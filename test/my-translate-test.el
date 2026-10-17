;;; my-translate-test.el --- Translation command tests -*- lexical-binding: t -*-

(require 'ert)
(require 'cl-lib)

;; Load real gt components without installing packages in the test process.
(unless (featurep 'prelude-packages)
  (provide 'prelude-packages))
(cl-letf (((symbol-function 'prelude-require-package) #'ignore))
  (require 'my-translate))

(defvar evil-visual-beginning nil)
(defvar evil-visual-end nil)

(ert-deftest my-translate-directions-and-selection ()
  (dolist (case '((my/translate-en2zh-selected en zh)
                  (my/translate-zh2en-selected zh en)))
    (dolist (visual '(nil t))
      (with-temp-buffer
        ;; Deliberately mixed text: language detection must not change direction.
        (insert "prefix Hello 世界 suffix")
        (let ((transient-mark-mode t)
              (gt-langs '(fr de))
              (gt-last-target '(fr de))
              (gt-taker-prompt t)
              (gt-taker-pick 'word)
              (evil-visual-beginning (and visual (copy-marker 8)))
              (evil-visual-end (and visual (copy-marker 16))))
          (unless visual
            (goto-char 8)
            (push-mark 16 t t)
            (activate-mark))
          (cl-letf (((symbol-function 'gt-start)
                     (lambda (translator)
                       (gt-take (oref translator taker) translator)
                       (should (equal (oref translator text) '("Hello 世界")))
                       (should (equal (oref translator target) (cdr case)))
                       (should (object-of-class-p (oref translator engines)
                                                 'gt-google-engine))
                       (should (object-of-class-p (oref translator render)
                                                 'gt-buffer-render)))))
            (call-interactively (car case)))
          (should (equal (buffer-string) "prefix Hello 世界 suffix")))))))

(ert-deftest my-translate-rejects-missing-or-blank-selection ()
  (dolist (command '(my/translate-en2zh-selected my/translate-zh2en-selected))
    (dolist (text '("" " \n\t"))
      (with-temp-buffer
        (insert text)
        (let ((transient-mark-mode t))
          (goto-char (point-min))
          (push-mark (point-max) t t)
          (activate-mark)
          (cl-letf (((symbol-function 'gt-start)
                     (lambda (_) (ert-fail "Unexpected translation request"))))
            (should-error (call-interactively command) :type 'user-error)))))))

;;; my-translate-test.el ends here
