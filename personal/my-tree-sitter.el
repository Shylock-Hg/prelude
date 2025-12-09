;;; -*- lexical-binding: t -*-

(require 'treesit)

(defvar my-init-dir (file-name-directory user-init-file))

(defvar my-tree-sitter-typst-src (expand-file-name "vendor/uben0/tree-sitter-typst" my-init-dir))
(defvar my-tree-sitter-cmake-src (expand-file-name "vendor/uyha/tree-sitter-cmake" my-init-dir))

(with-eval-after-load 'treesit
  (add-to-list 'treesit-language-source-alist
               `(typst ,my-tree-sitter-typst-src
                       ))
  (add-to-list 'treesit-language-source-alist
               `(cmake ,my-tree-sitter-cmake-src
                       ))
  )

(provide 'my-tree-sitter)
