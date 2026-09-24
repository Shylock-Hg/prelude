;;; my-utils-test.el --- Tests for personal utility commands. -*- lexical-binding: t; -*-

(require 'ert)
(require 'my-utils)
(require 'evil nil t)

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
          (save-window-excursion (my-open-file-selected)))
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
    (should-error (my-open-file-selected) :type 'user-error)))

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
          (should-error (my-open-file-selected) :type 'user-error))
      (kill-buffer source))))

(ert-deftest my-open-file-selected-errors-for-missing-file ()
  (let ((missing (make-temp-file "my-utils-test-missing-")))
    (delete-file missing)
    (should-error (my-utils-test--run missing #'my-utils-test--active-region)
                  :type 'user-error)))

(provide 'my-utils-test)
;;; my-utils-test.el ends here
