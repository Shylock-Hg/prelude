;;; -*- lexical-binding: t; -*-

(defconst my-vterm-test-bootstrap--repo-root
  (expand-file-name ".."
                    (file-name-directory
                     (or load-file-name buffer-file-name))))

(defun my-vterm-test-bootstrap--add-package-path (variable library)
  "Add VARIABLE's directory to `load-path' and require LIBRARY.el there."
  (let ((directory (getenv variable)))
    (unless (and directory (file-directory-p directory)
                 (file-exists-p (expand-file-name
                                 (concat library ".el") directory)))
      (error "Set %s to a directory containing %s.el"
             variable library))
    (add-to-list 'load-path (expand-file-name directory))))

(add-to-list 'load-path
             (expand-file-name "personal" my-vterm-test-bootstrap--repo-root))
(my-vterm-test-bootstrap--add-package-path "PRELUDE_EVIL_DIR" "evil")
(my-vterm-test-bootstrap--add-package-path "PRELUDE_VTERM_DIR" "vterm")

;; The tests load personal configuration without installing its full package
;; set or starting an Emacs server.
(defmacro use-package (&rest _arguments) nil)
(defun prelude-require-packages (&rest _packages) nil)
(provide 'prelude-packages)

(require 'evil)
;; Evil 1.15 leaves this initialization sentinel unbound after startup, while
;; its normal-state post-command hook reads it outside initialization too.
(unless (boundp 'evil-mode-buffers)
  (setq evil-mode-buffers nil))
(require 'vterm)
(require 'server)
(advice-add 'server-start :override #'ignore)
(unwind-protect
    (require 'my-config)
  (advice-remove 'server-start #'ignore))
(require 'my-vterm)

(provide 'my-vterm-test-bootstrap)
;;; my-vterm-test-bootstrap.el ends here
