;;; -*- lexical-binding: t -*-

(require 'treesit)
(require 'my-vendor)

(defvar my-tree-sitter-typst-src (my-vendor-dest "uben0" "tree-sitter-typst"))
(defvar my-tree-sitter-cmake-src (my-vendor-dest "uyha" "tree-sitter-cmake"))
(defvar my-tree-sitter-rust-src (my-vendor-dest "tree-sitter" "tree-sitter-rust"))
(defvar my-tree-sitter-tlaplus-src (my-vendor-dest "tlaplus-community" "tree-sitter-tlaplus"))

(my-vendor-install-git "github.com" "uben0" "tree-sitter-typst")
(my-vendor-install-git "github.com" "uyha" "tree-sitter-cmake")
(my-vendor-install-git "github.com" "tree-sitter" "tree-sitter-rust")
(my-vendor-install-git "github.com" "tlaplus-community" "tree-sitter-tlaplus")

(with-eval-after-load 'treesit
  (add-to-list 'treesit-language-source-alist
               `(typst ,my-tree-sitter-typst-src
                       ))
  (add-to-list 'treesit-language-source-alist
               `(cmake ,my-tree-sitter-cmake-src
                       ))
  (add-to-list 'treesit-language-source-alist
               `(rust ,my-tree-sitter-rust-src
                       ))
  (add-to-list 'treesit-language-source-alist
               `(tlaplus ,my-tree-sitter-tlaplus-src
                       ))
  )

(provide 'my-tree-sitter)
