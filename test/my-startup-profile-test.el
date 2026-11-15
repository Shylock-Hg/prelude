;;; my-startup-profile-test.el --- Startup profiling regressions -*- lexical-binding: t; -*-

(require 'ert)

(defconst my-startup-profile-test--repo-root
  (expand-file-name ".."
                    (file-name-directory
                     (or load-file-name buffer-file-name)))
  "Repository root for this test file.")

(defconst my-startup-profile-test--early-init
  (expand-file-name "early-init.el" my-startup-profile-test--repo-root)
  "Prelude's early init file.")

(defun my-startup-profile-test--emacs ()
  "Return the Emacs executable running this test."
  (expand-file-name invocation-name invocation-directory))

(defun my-startup-profile-test--run (profile &rest args)
  "Run a child Emacs with ARGS, enabling profiling when PROFILE is non-nil."
  (let ((buffer (generate-new-buffer " *my-startup-profile-test-output*"))
        (process-environment (copy-sequence process-environment)))
    (unwind-protect
        (progn
          (setenv "PRELUDE_PROFILE_STARTUP" (and profile "1"))
          (let ((status
                 (apply #'call-process
                        (my-startup-profile-test--emacs) nil buffer nil
                        (append (list "--batch" "-Q" "-l"
                                      my-startup-profile-test--early-init)
                                args))))
            (with-current-buffer buffer
              (unless (zerop status)
                (error "Child Emacs failed with status %s:\n%s"
                       status (buffer-string)))
              (buffer-string))))
      (kill-buffer buffer))))

(defun my-startup-profile-test--write-fixture (directory name contents)
  "Write CONTENTS to NAME in DIRECTORY and return its path."
  (let ((file (expand-file-name name directory)))
    (with-temp-file file
      (insert contents))
    file))

(defmacro my-startup-profile-test--with-directory (&rest body)
  "Run BODY with `directory' bound to a temporary directory."
  (declare (indent 0) (debug t))
  `(let ((directory (make-temp-file "my-startup-profile-test-" t)))
     (unwind-protect
         (progn ,@body)
       (delete-directory directory t))))

(ert-deftest my-startup-profile-records-explicit-load ()
  (my-startup-profile-test--with-directory
    (let* ((file
            (my-startup-profile-test--write-fixture
             directory "explicit-fixture.el"
             ";;; explicit-fixture.el --- fixture -*- lexical-binding: t; -*-\n(provide 'explicit-fixture)\n"))
           (form (format "(progn (load %S) (princ \"RESULT=\") (prin1 (mapcar #'car prelude-startup-load-times)))"
                         file))
           (output (my-startup-profile-test--run t "--eval" form)))
      (should (string-match-p (concat "RESULT=.*" (regexp-quote file)) output)))))

(ert-deftest my-startup-profile-records-require ()
  (my-startup-profile-test--with-directory
    (let* ((file
            (my-startup-profile-test--write-fixture
             directory "require-fixture.el"
             ";;; require-fixture.el --- fixture -*- lexical-binding: t; -*-\n(provide 'require-fixture)\n"))
           (form (format "(progn (add-to-list 'load-path %S) (require 'require-fixture) (princ \"RESULT=\") (prin1 (mapcar #'car prelude-startup-load-times)))"
                         directory))
           (output (my-startup-profile-test--run t "--eval" form)))
      (should (string-match-p (concat "RESULT=.*" (regexp-quote file)) output)))))

(ert-deftest my-startup-profile-records-autoload ()
  (my-startup-profile-test--with-directory
    (let* ((file
            (my-startup-profile-test--write-fixture
             directory "autoload-fixture.el"
             ";;; autoload-fixture.el --- fixture -*- lexical-binding: t; -*-\n(defun autoload-fixture-function () t)\n(provide 'autoload-fixture)\n"))
           (form (format "(progn (add-to-list 'load-path %S) (autoload 'autoload-fixture-function \"autoload-fixture\" nil t) (autoload-fixture-function) (princ \"RESULT=\") (prin1 (mapcar #'car prelude-startup-load-times)))"
                         directory))
           (output (my-startup-profile-test--run t "--eval" form)))
      (should (string-match-p (concat "RESULT=.*" (regexp-quote file)) output)))))

(ert-deftest my-startup-profile-autoload-times-only-resolution ()
  (my-startup-profile-test--with-directory
    (my-startup-profile-test--write-fixture
     directory "autoload-timing-fixture.el"
     ";;; autoload-timing-fixture.el --- fixture -*- lexical-binding: t; -*-\n(defun autoload-timing-fixture () (sleep-for 0.1))\n(provide 'autoload-timing-fixture)\n")
    (let* ((form (format "(progn (add-to-list 'load-path %S) (autoload 'autoload-timing-fixture \"autoload-timing-fixture\" nil t) (setq prelude-startup-load-times nil) (autoload-timing-fixture) (let* ((file (locate-library \"autoload-timing-fixture\")) (initial (length prelude-startup-load-times)) (load-time (cdr (assoc file prelude-startup-load-times))) (count 0)) (dolist (entry prelude-startup-load-times) (when (equal (car entry) file) (setq count (1+ count)))) (autoload-timing-fixture) (autoload-timing-fixture) (princ \"RESULT=\") (prin1 (list initial (length prelude-startup-load-times) count (< load-time 0.05)))))"
                         directory))
           (output (my-startup-profile-test--run t "--eval" form)))
      (should (string-match-p "RESULT=(1 1 1 t)" output)))))

(ert-deftest my-startup-profile-is-disabled-by-default ()
  (let* ((form "(progn (princ \"RESULT=\") (prin1 (list (advice-member-p 'prelude--profile-startup-load 'load) (advice-member-p 'prelude--profile-startup-require 'require) (advice-member-p 'prelude--profile-startup-load-with-code-conversion 'load-with-code-conversion) (advice-member-p 'prelude--profile-startup-autoload-declaration 'autoload) (advice-member-p 'prelude--profile-startup-autoload-load 'autoload-do-load) prelude--startup-profile-autoload-advice)))")
         (output (my-startup-profile-test--run nil "--eval" form)))
    (should (string-match-p "RESULT=(nil nil nil nil nil nil)" output))))

(ert-deftest my-startup-profile-removes-instrumentation-at-startup ()
  (my-startup-profile-test--with-directory
    (my-startup-profile-test--write-fixture
     directory "cleanup-fixture.el"
     ";;; cleanup-fixture.el --- fixture -*- lexical-binding: t; -*-\n(provide 'cleanup-fixture)\n")
    (let* ((form (format "(progn (add-to-list 'load-path %S) (require 'cleanup-fixture) (princ \"RESULT=\") (prin1 (list (> (length prelude-startup-load-times) 0) (> (length prelude--startup-profile-autoload-advice) 0))) (run-hooks 'emacs-startup-hook) (princ \" AFTER=\") (prin1 (list (advice-member-p 'prelude--profile-startup-load 'load) (advice-member-p 'prelude--profile-startup-require 'require) (advice-member-p 'prelude--profile-startup-load-with-code-conversion 'load-with-code-conversion) (advice-member-p 'prelude--profile-startup-autoload-declaration 'autoload) (advice-member-p 'prelude--profile-startup-autoload-load 'autoload-do-load) prelude--startup-profile-autoload-advice)))"
                         directory))
           (output (my-startup-profile-test--run t "--eval" form)))
      (should (string-match-p "RESULT=(t t)" output))
      (should (string-match-p "AFTER=(nil nil nil nil nil nil)" output)))))

;;; my-startup-profile-test.el ends here
