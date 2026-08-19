;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'cmake-ts-mode)

(require 'treesit)

(treesit-install-language-grammar 'cmake)

;; OUTSIDE require to install neocmakelsp first
(defun my/setup-neocmakelsp ()
  "Setup neocmakelsp for cmake-ts-mode."
  (require 'eglot)
  (add-to-list 'eglot-server-programs '((cmake-ts-mode) . ("neocmakelsp" "stdio")))
  (eglot-ensure))

(use-package cmake-ts-mode
  :hook (cmake-ts-mode . my/setup-neocmakelsp))

(provide 'my-cmake)
