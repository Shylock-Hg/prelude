;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'cmake-ts-mode)

(require 'my-tree-sitter)

(my-tree-sitter-ensure-grammar 'cmake)

;; OUTSIDE require to install neocmakelsp first
(defun my/setup-neocmakelsp ()
  "Setup neocmakelsp for cmake-ts-mode."
  (require 'eglot)
  (add-to-list 'eglot-server-programs '((cmake-ts-mode) . ("neocmakelsp" "stdio")))
  (eglot-ensure))

(use-package cmake-ts-mode
  :hook (cmake-ts-mode . my/setup-neocmakelsp))

(provide 'my-cmake)
