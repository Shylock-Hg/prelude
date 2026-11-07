;;; my-translate-test.el --- Translation command tests -*- lexical-binding: t -*-

(require 'ert)
(require 'cl-lib)

;; Load real gt components without installing packages in the test process.
(defvar my-translate-test-required-packages nil)
(unless (featurep 'prelude-packages)
  (provide 'prelude-packages))
(cl-letf (((symbol-function 'prelude-require-package)
           (lambda (package) (push package my-translate-test-required-packages))))
  (require 'my-translate))

(ert-deftest my-translate-requires-posframe ()
  (should (memq 'gt my-translate-test-required-packages))
  (should (memq 'posframe my-translate-test-required-packages))
  (should-not gt-pop-posframe-forecolor)
  (should-not gt-pop-posframe-backcolor))

(ert-deftest my-translate-posframe-follows-theme-colors ()
  (let ((foreground "#123456")
        (background "#abcdef"))
    (cl-letf (((symbol-function 'face-attribute)
               (lambda (face attribute &optional _frame _inherit)
                 (should (eq face 'default))
                 (pcase attribute
                   (:foreground foreground)
                   (:background background)
                   (_ (ert-fail (format "Unexpected face attribute: %s" attribute)))))))
      (let ((render (my-translate--posframe-render)))
        (should (eq (eieio-object-class render) 'gt-posframe-pop-render))
        (should (equal (oref render forecolor) foreground))
        (should (equal (oref render backcolor) background))))))

(ert-deftest my-translate-posframe-ignores-unspecified-face-colors ()
  (cl-letf (((symbol-function 'face-attribute)
             (lambda (_face attribute &optional _frame _inherit)
               (pcase attribute
                 (:foreground "unspecified-fg")
                 (:background "unspecified-bg")))))
    (let ((render (my-translate--posframe-render)))
      (should-not (oref render forecolor))
      (should-not (oref render backcolor)))))

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
                       (should (eq (eieio-object-class (oref translator render))
                                   'gt-posframe-pop-render)))))
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
