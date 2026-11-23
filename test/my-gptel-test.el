;;; my-gptel-test.el --- gptel startup regressions -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'package)

(defconst my-gptel-test--file load-file-name)
(defconst my-gptel-test--personal-directory
  (expand-file-name "../personal" (file-name-directory my-gptel-test--file)))

(defun my-gptel-test--load-config (package-directory on-load-path)
  "Load the personal config against the fixture in PACKAGE-DIRECTORY.
ON-LOAD-PATH is non-nil if Emacs was started with the fixture on `load-path'."
  (require 'use-package)
  (setq package-user-dir (file-name-directory package-directory)
        package-directory-list nil
        package-quickstart-file (expand-file-name "package-quickstart.el"
                                                  package-user-dir))
  (package-initialize)
  (should (package-installed-p 'gptel))
  (let ((autoloads (expand-file-name "gptel-autoloads.el" package-directory)))
    (should (eq (not (null (locate-library "gptel"))) on-load-path))
    (should-not (file-exists-p autoloads))
    (should-not (fboundp 'gptel-make-gemini))
    (provide 'prelude-packages)
    (cl-letf (((symbol-function 'prelude-require-package)
               (lambda (package) (should (package-installed-p package)))))
      (require 'my-gptel))
    (should (file-exists-p autoloads))
    (should (featurep 'gptel-gemini))))

(defun my-gptel-test--recover-autoloads (on-load-path)
  "Test recovery with the package directory already ON-LOAD-PATH or off it."
  (let* ((directory (make-temp-file "my-gptel-test-" t))
         (package-directory (expand-file-name "gptel-1.0" directory))
         (load-path-args (when on-load-path (list "-L" package-directory)))
         (load-config (prin1-to-string
                       `(my-gptel-test--load-config ,package-directory ,on-load-path))))
    (unwind-protect
        (progn
          (make-directory package-directory)
          (with-temp-file (expand-file-name "gptel-pkg.el" package-directory)
            (insert "(define-package \"gptel\" \"1.0\" \"Test fixture\" nil)\n"))
          (with-temp-file (expand-file-name "gptel.el" package-directory)
            (insert ";;; -*- lexical-binding: t -*-\n"
                    "(defun gptel-make-openai (&rest args) args)\n"
                    "(defun gptel-make-xai (&rest args) args)\n"
                    "(provide 'gptel)\n"))
          (with-temp-file (expand-file-name "gptel-gemini.el" package-directory)
            (insert ";;; -*- lexical-binding: t -*-\n"
                    ";;;###autoload\n"
                    "(defun gptel-make-gemini (&rest args) args)\n"
                    "(provide 'gptel-gemini)\n"))
          (with-temp-buffer
            (let ((status
                   (apply #'call-process
                          (expand-file-name invocation-name invocation-directory)
                          nil t nil "--batch" "-Q"
                          "-L" my-gptel-test--personal-directory
                          "-l" my-gptel-test--file
                          (append load-path-args (list "--eval" load-config)))))
              (unless (equal status 0)
                (ert-fail (buffer-string))))))
      (delete-directory directory t))))

(ert-deftest my-gptel-recovers-missing-autoloads-on-load-path ()
  (my-gptel-test--recover-autoloads t))

(ert-deftest my-gptel-recovers-missing-autoloads-off-load-path ()
  (my-gptel-test--recover-autoloads nil))

;;; my-gptel-test.el ends here
