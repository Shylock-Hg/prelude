;;; my-utils-test.el --- Tests for personal utility commands. -*- lexical-binding: t; -*-

(require 'ert)
(require 'my-utils)
(require 'evil nil t)

;; Keep the optional Evil marker variables dynamically bindable in tests when
;; Evil is not installed; Evil's own definitions are preserved when present.
(defvar evil-visual-beginning nil)
(defvar evil-visual-end nil)

(defun my-utils-test--write-lines (file count)
  (with-temp-file file
    (dotimes (index count)
      (insert (format "line %d\n" (1+ index))))))

(defun my-utils-test--line (buffer position)
  (with-current-buffer buffer
    (line-number-at-pos position t)))

(defun my-utils-test--run (text setup)
  "Insert TEXT in a fresh source buffer, call SETUP, then open the selection.
Return the opened buffer or the signaled error."
  (let ((source (generate-new-buffer " *my-utils-test-source*"))
        (transient-mark-mode t))
    (unwind-protect
        (progn
          (switch-to-buffer source)
          (insert text)
          (funcall setup)
          (save-window-excursion (my/open-file-selected)))
      (when (buffer-live-p source)
        (kill-buffer source)))))

(defun my-utils-test--active-region ()
  "Select the whole buffer with an ordinary active region."
  (goto-char (point-min))
  (push-mark (point-max) t t)
  (activate-mark))

(defun my-utils-test--evil-selection (&optional deactivate)
  "Select the whole buffer with an Evil visual selection.
When DEACTIVATE is non-nil exit visual state before the command runs,
mimicking the region being deactivated by the `C-,' minibuffer."
  (require 'evil)
  (unless (boundp 'evil-mode-buffers)
    (setq evil-mode-buffers nil))
  (evil-mode 1)
  (goto-char (point-min))
  (evil-visual-select (point-min) (point-max) 'char)
  (when deactivate
    (evil-exit-visual-state)))

(defun my-utils-test--cleanup (file buffer)
  (when (buffer-live-p buffer)
    (kill-buffer buffer))
  (when (file-exists-p file)
    (delete-file file)))

(ert-deftest my-open-file-selected-opens-plain-path-from-region ()
  (let ((file (make-temp-file "my-utils-test-"))
        target)
    (unwind-protect
        (progn
          (my-utils-test--write-lines file 3)
          (setq target (my-utils-test--run file #'my-utils-test--active-region))
          (should (equal target (get-file-buffer file))))
      (my-utils-test--cleanup file target))))

(ert-deftest my-open-file-selected-opens-path-at-line-from-region ()
  (let ((file (make-temp-file "my-utils-test-"))
        target)
    (unwind-protect
        (progn
          (my-utils-test--write-lines file 12)
          (setq target
                (my-utils-test--run (format "%s:7" file)
                                    #'my-utils-test--active-region))
          (should (equal target (get-file-buffer file)))
          (should (= (my-utils-test--line target
                                          (with-current-buffer target (point)))
                     7)))
      (my-utils-test--cleanup file target))))

(ert-deftest my-open-file-selected-uses-active-evil-selection ()
  (skip-unless (featurep 'evil))
  (let ((file (make-temp-file "my-utils-test-"))
        target)
    (unwind-protect
        (progn
          (my-utils-test--write-lines file 3)
          (setq target
                (my-utils-test--run file
                                    (lambda ()
                                      (my-utils-test--evil-selection))))
          (should (equal target (get-file-buffer file))))
      (my-utils-test--cleanup file target))))

(ert-deftest my-open-file-selected-uses-last-evil-selection ()
  "The command still works when `C-,' leaves Evil with a deactivated region."
  (skip-unless (featurep 'evil))
  (let ((file (make-temp-file "my-utils-test-"))
        target)
    (unwind-protect
        (progn
          (my-utils-test--write-lines file 12)
          (setq target
                (my-utils-test--run (format "%s:5" file)
                                    (lambda ()
                                      (my-utils-test--evil-selection t))))
          (should (equal target (get-file-buffer file)))
          (should (= (my-utils-test--line target
                                          (with-current-buffer target (point)))
                     5)))
      (my-utils-test--cleanup file target))))

(ert-deftest my-open-file-selected-errors-without-selection ()
  (with-temp-buffer
    (should-error (my/open-file-selected) :type 'user-error)))

(ert-deftest my-open-file-selected-errors-for-empty-region ()
  (let ((source (generate-new-buffer " *my-utils-test-source*"))
        (transient-mark-mode t))
    (unwind-protect
        (progn
          (switch-to-buffer source)
          (insert " \t\n ")
          (goto-char (point-min))
          (push-mark (point-max) t t)
          (activate-mark)
          (should-error (my/open-file-selected) :type 'user-error))
      (kill-buffer source))))

(ert-deftest my-open-file-selected-errors-for-missing-file ()
  (let ((missing (make-temp-file "my-utils-test-missing-")))
    (delete-file missing)
    (should-error (my-utils-test--run missing #'my-utils-test--active-region)
                  :type 'user-error)))

(ert-deftest my--selected-text-ignores-partially-bound-evil-markers ()
  (with-temp-buffer
    (insert "selection")
    (let ((evil-visual-beginning (copy-marker (point-min)))
          (evil-visual-end nil))
      (makunbound 'evil-visual-end)
      (should-not (my--selected-text))))
  (with-temp-buffer
    (insert "selection")
    (let ((evil-visual-beginning nil)
          (evil-visual-end (copy-marker (point-max))))
      (makunbound 'evil-visual-beginning)
      (should-not (my--selected-text)))))

(ert-deftest my--selected-text-ignores-detached-evil-markers ()
  (with-temp-buffer
    (insert "selection")
    (let ((beginning (copy-marker (point-min)))
          (end (copy-marker (point-max))))
      (set-marker beginning nil)
      (let ((evil-visual-beginning beginning)
            (evil-visual-end end))
        (should-not (my--selected-text))))))

(ert-deftest my--selected-text-ignores-markers-from-a-dead-buffer ()
  (let ((source (generate-new-buffer " *my-utils-dead-marker*"))
        beginning end)
    (unwind-protect
        (progn
          (with-current-buffer source
            (insert "foreign selection")
            (setq beginning (copy-marker (point-min))
                  end (copy-marker (point-max))))
          (kill-buffer source)
          (with-temp-buffer
            (insert "current selection")
            (let ((evil-visual-beginning beginning)
                  (evil-visual-end end))
              (should-not (my--selected-text)))))
      (when (buffer-live-p source)
        (kill-buffer source)))))

(ert-deftest my--selected-text-ignores-markers-from-another-buffer ()
  (let ((source (generate-new-buffer " *my-utils-foreign-marker*"))
        beginning end)
    (unwind-protect
        (progn
          (with-current-buffer source
            (insert "foreign selection")
            (setq beginning (copy-marker (point-min))
                  end (copy-marker (+ (point-min) 7))))
          (with-temp-buffer
            (insert "current selection")
            (let ((evil-visual-beginning beginning)
                  (evil-visual-end end))
              (should-not (my--selected-text))))
          (set-marker beginning nil)
          (set-marker end nil))
      (when (buffer-live-p source)
        (kill-buffer source)))))

(ert-deftest my--selected-text-ignores-markers-outside-a-narrowed-buffer ()
  (with-temp-buffer
    (insert "0123456789")
    (let ((evil-visual-beginning nil)
          (evil-visual-end nil))
      (dolist (positions '((1 5) (4 11)))
        (save-restriction
          (narrow-to-region 3 9)
          (setq evil-visual-beginning (copy-marker (car positions))
                evil-visual-end (copy-marker (cadr positions)))
          (should-not (my--selected-text)))))))

(ert-deftest my--selected-text-preserves-active-region-precedence ()
  (let ((source (generate-new-buffer " *my-utils-active-region-marker*"))
        beginning end)
    (unwind-protect
        (progn
          (with-current-buffer source
            (insert "foreign selection")
            (setq beginning (copy-marker (point-min))
                  end (copy-marker (+ (point-min) 7))))
          (with-temp-buffer
            (insert "active region")
            (let ((transient-mark-mode t)
                  (evil-visual-beginning beginning)
                  (evil-visual-end end))
              (goto-char (point-min))
              (push-mark (+ (point-min) 6) t t)
              (activate-mark)
              (should (equal (my--selected-text) "active"))))
          (set-marker beginning nil)
          (set-marker end nil))
      (when (buffer-live-p source)
        (kill-buffer source)))))

(ert-deftest my--selected-text-uses-valid-last-evil-selection-markers ()
  (with-temp-buffer
    (insert "a valid selection")
    (let ((evil-visual-beginning (copy-marker 3))
          (evil-visual-end (copy-marker 8)))
      (should (equal (my--selected-text) "valid")))))

(ert-deftest my--selected-text-rejects-empty-and-reversed-markers ()
  (with-temp-buffer
    (insert "selection")
    (let ((evil-visual-beginning nil)
          (evil-visual-end nil))
      (dolist (positions '((3 3) (7 2)))
        (setq evil-visual-beginning (copy-marker (car positions))
              evil-visual-end (copy-marker (cadr positions)))
        (should-not (my--selected-text))
        (set-marker evil-visual-beginning nil)
        (set-marker evil-visual-end nil)))))

(ert-deftest my-open-file-selected-errors-for-invalid-last-evil-selection ()
  (with-temp-buffer
    (insert "selection")
    (let ((evil-visual-beginning (copy-marker 1))
          (evil-visual-end (copy-marker 5)))
      (set-marker evil-visual-end nil)
      (should-error (my/open-file-selected) :type 'user-error))))

(provide 'my-utils-test)
;;; my-utils-test.el ends here
