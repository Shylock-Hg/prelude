;;; my-sudo-edit.el --- Edit files as another user -*- lexical-binding: t; -*-

(require 'prelude-packages)

(prelude-require-package 'sudo-edit)

(use-package sudo-edit
  :bind ("C-c M-s" . sudo-edit))

(provide 'my-sudo-edit)
;;; my-sudo-edit.el ends here
