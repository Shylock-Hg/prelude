;;; my-vendor-test.el --- Tests for personal vendor cloning. -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)
(require 'my-vendor)

(defmacro my-vendor-test--with-repository (&rest body)
  "Run BODY with a temporary vendor root, USER, REPO, and DESTINATION."
  (declare (indent 0) (debug t))
  `(let* ((my-vendor-dir (make-temp-file "my-vendor-test-" t))
          (user "example-user")
          (repo "example-repo")
          (destination (my-vendor-dest user repo)))
     (unwind-protect
         (progn ,@body)
       (when (file-directory-p my-vendor-dir)
         (delete-directory my-vendor-dir t)))))

(defun my-vendor-test--write-staged-file (staging name contents)
  "Write CONTENTS to NAME inside STAGING."
  (with-temp-file (expand-file-name name staging)
    (insert contents)))

(ert-deftest my-vendor-install-git-validates-arguments ()
  (should-error (my-vendor-install-git nil "user" "repo"))
  (should-error (my-vendor-install-git "git.example" "" "repo"))
  (should-error (my-vendor-dest "user" nil)))

(ert-deftest my-vendor-install-git-clones-and-returns-t ()
  (my-vendor-test--with-repository
    (let ((calls 0)
          staging)
      (cl-letf (((symbol-function 'call-process)
                 (lambda (program _input output-destination _display &rest arguments)
                   (setq calls (1+ calls)
                         staging (car (last arguments)))
                   (should (equal program "git"))
                   (should (eq output-destination t))
                   (should (equal arguments
                                  (list "clone" "--depth=1"
                                        "https://git.example/example-user/example-repo.git"
                                        staging)))
                   (should (equal (file-name-directory staging)
                                  (file-name-directory destination)))
                   (my-vendor-test--write-staged-file
                    staging "README" "cloned")
                   (insert "Cloning complete\n")
                   0)))
        (should (eq (my-vendor-install-git "git.example" user repo) t)))
      (should (= calls 1))
      (should (file-directory-p destination))
      (should (equal (with-temp-buffer
                       (insert-file-contents (expand-file-name "README" destination))
                       (buffer-string))
                     "cloned"))
      (should-not (file-exists-p staging)))))

(ert-deftest my-vendor-install-git-skips-existing-destination-and-returns-nil ()
  (my-vendor-test--with-repository
    (make-directory destination t)
    (my-vendor-test--write-staged-file destination "MANUAL" "kept")
    (cl-letf (((symbol-function 'call-process)
               (lambda (&rest _arguments)
                 (ert-fail "Existing vendor directories must not be cloned"))))
      (should-not (my-vendor-install-git "git.example" user repo)))
    (should (equal (with-temp-buffer
                     (insert-file-contents (expand-file-name "MANUAL" destination))
                     (buffer-string))
                   "kept"))))

(ert-deftest my-vendor-install-git-protects-existing-file-destination ()
  (my-vendor-test--with-repository
    (make-directory (file-name-directory destination) t)
    (with-temp-file destination
      (insert "keep this file"))
    (cl-letf (((symbol-function 'call-process)
               (lambda (&rest _arguments)
                 (ert-fail "An existing file destination must not be cloned"))))
      (should-error (my-vendor-install-git "git.example" user repo)))
    (should (equal (with-temp-buffer
                     (insert-file-contents destination)
                     (buffer-string))
                   "keep this file"))))

(ert-deftest my-vendor-install-git-protects-dangling-symlink-destination ()
  (my-vendor-test--with-repository
    (make-directory (file-name-directory destination) t)
    (make-symbolic-link (expand-file-name "missing-target" my-vendor-dir)
                        destination)
    (cl-letf (((symbol-function 'call-process)
               (lambda (&rest _arguments)
                 (ert-fail "A dangling symlink destination must not be cloned"))))
      (should-error (my-vendor-install-git "git.example" user repo)))
    (should (file-symlink-p destination))
    (should-not (file-exists-p destination))))

(ert-deftest my-vendor-install-git-cleans-failed-stage-and-allows-retry ()
  (my-vendor-test--with-repository
    (let ((attempt 0)
          stages
          failure)
      (cl-letf (((symbol-function 'call-process)
                 (lambda (_program _input _destination _display &rest arguments)
                   (setq attempt (1+ attempt))
                   (let ((staging (car (last arguments))))
                     (push staging stages)
                     (if (= attempt 1)
                         (progn
                           (my-vendor-test--write-staged-file
                            staging "partial" "incomplete")
                           (insert "fatal: simulated clone failure\n")
                           128)
                       (my-vendor-test--write-staged-file
                        staging "README" "retry succeeded")
                       (insert "Cloning complete\n")
                       0)))))
        (setq failure
              (condition-case err
                  (progn (my-vendor-install-git "git.example" user repo) nil)
                (error (error-message-string err))))
        (should (string-match-p "fatal: simulated clone failure" failure))
        (should-not (file-exists-p destination))
        (should (eq (my-vendor-install-git "git.example" user repo) t)))
      (should (= attempt 2))
      (should (= (length stages) 2))
      (dolist (staging stages)
        (should-not (file-exists-p staging)))
      (should (file-exists-p (expand-file-name "README" destination)))
      (should-not (file-exists-p (expand-file-name "partial" destination))))))

(ert-deftest my-vendor-install-git-handles-process-termination-string ()
  (my-vendor-test--with-repository
    (let (staging failure)
      (cl-letf (((symbol-function 'call-process)
                 (lambda (_program _input _destination _display &rest arguments)
                   (setq staging (car (last arguments)))
                   (my-vendor-test--write-staged-file staging "partial" "incomplete")
                   (insert "fatal: process interrupted\n")
                   "Killed by signal SIGTERM")))
        (setq failure
              (condition-case err
                  (progn (my-vendor-install-git "git.example" user repo) nil)
                (error (error-message-string err)))))
      (should (string-match-p "Killed by signal SIGTERM" failure))
      (should (string-match-p "fatal: process interrupted" failure))
      (should-not (file-exists-p destination))
      (should-not (file-exists-p staging)))))

(ert-deftest my-vendor-install-git-cleans-stage-on-interruption ()
  (my-vendor-test--with-repository
    (let (staging interrupted)
      (cl-letf (((symbol-function 'call-process)
                 (lambda (_program _input _destination _display &rest arguments)
                   (setq staging (car (last arguments)))
                   (my-vendor-test--write-staged-file staging "partial" "incomplete")
                   (signal 'quit nil))))
        (condition-case nil
            (my-vendor-install-git "git.example" user repo)
          (quit (setq interrupted t))))
      (should interrupted)
      (should-not (file-exists-p staging))
      (should-not (file-exists-p destination)))))

(ert-deftest my-vendor-install-git-preserves-destination-created-during-clone ()
  (my-vendor-test--with-repository
    (let (staging)
      (cl-letf (((symbol-function 'call-process)
                 (lambda (_program _input _destination _display &rest arguments)
                   (setq staging (car (last arguments)))
                   (my-vendor-test--write-staged-file staging "README" "clone")
                   (make-directory destination t)
                   (my-vendor-test--write-staged-file
                    destination "MANUAL" "keep this directory")
                   0)))
        (should-error (my-vendor-install-git "git.example" user repo)))
      (should (equal (with-temp-buffer
                       (insert-file-contents (expand-file-name "MANUAL" destination))
                       (buffer-string))
                     "keep this directory"))
      (should-not (file-exists-p (expand-file-name "README" destination)))
      (should-not (file-exists-p staging)))))

(ert-deftest my-vendor-install-git-protects-directory-created-before-rename ()
  (my-vendor-test--with-repository
    (let ((real-rename-file (symbol-function 'rename-file))
          staging)
      (cl-letf (((symbol-function 'call-process)
                 (lambda (_program _input _destination _display &rest arguments)
                   (setq staging (car (last arguments)))
                   (my-vendor-test--write-staged-file staging "README" "clone")
                   0))
                ((symbol-function 'rename-file)
                 (lambda (old-name new-name &optional ok-if-already-exists)
                   ;; Simulate another installer winning after the explicit
                   ;; destination check and immediately before this rename.
                   (make-directory new-name)
                   (my-vendor-test--write-staged-file
                    new-name "MANUAL" "preserve this directory")
                   (funcall real-rename-file old-name new-name
                            ok-if-already-exists))))
        (should-error (my-vendor-install-git "git.example" user repo)))
      (should (equal (with-temp-buffer
                       (insert-file-contents
                        (expand-file-name "MANUAL" destination))
                       (buffer-string))
                     "preserve this directory"))
      (should-not (file-exists-p (expand-file-name "README" destination)))
      (should-not (file-exists-p staging)))))

(provide 'my-vendor-test)
;;; my-vendor-test.el ends here
