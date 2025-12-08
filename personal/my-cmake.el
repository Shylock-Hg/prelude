;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'cmake-ts-mode)

(require 'treesit)

(treesit-install-language-grammar 'cmake)

;; OUTSIDE require to install neocmakelsp first
(use-package cmake-ts-mode
  :config
  (add-hook 'cmake-ts-mode-hook
    (defun setup-neocmakelsp ()
      (require 'eglot)
      (add-to-list 'eglot-server-programs `((cmake-ts-mode) . ("neocmakelsp" "stdio")))
      (eglot-ensure))))

(provide 'my-cmake)
