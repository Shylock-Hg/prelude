;;; -*- lexical-binding: t; -*-

(defconst my-eat-test-bootstrap--repo-root
  (expand-file-name ".."
                    (file-name-directory
                     (or load-file-name buffer-file-name))))

(defun my-eat-test-bootstrap--add-package-path (variable library)
  "Add VARIABLE's directory to `load-path' and require LIBRARY.el there."
  (let ((directory (getenv variable)))
    (unless (and directory (file-directory-p directory)
                 (file-exists-p (expand-file-name
                                 (concat library ".el") directory)))
      (error "Set %s to a directory containing %s.el"
             variable library))
    (add-to-list 'load-path (expand-file-name directory))))

(add-to-list 'load-path
             (expand-file-name "personal" my-eat-test-bootstrap--repo-root))
(my-eat-test-bootstrap--add-package-path "PRELUDE_EVIL_DIR" "evil")
(my-eat-test-bootstrap--add-package-path "PRELUDE_EAT_DIR" "eat")

;; The tests load the personal configuration without installing its full
;; package set or starting an Emacs server.
(defmacro use-package (&rest _arguments) nil)
(defun prelude-require-packages (&rest _packages) nil)
(defun prelude-require-package (&rest _packages) nil)
(provide 'prelude-packages)

(require 'evil)
(require 'eat)
(require 'server)
(advice-add 'server-start :override #'ignore)
(unwind-protect
    (require 'my-config)
  (advice-remove 'server-start #'ignore))
(require 'my-eat)

(provide 'my-eat-test-bootstrap)
;;; my-eat-test-bootstrap.el ends here
