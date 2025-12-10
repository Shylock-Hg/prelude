;;; -*- lexical-binding: t -*-

(require 'treesit)

(defvar my-init-dir (file-name-directory user-init-file))

(defvar my-tree-sitter-typst-src (expand-file-name "vendor/uben0/tree-sitter-typst" my-init-dir))
(defvar my-tree-sitter-cmake-src (expand-file-name "vendor/uyha/tree-sitter-cmake" my-init-dir))

(defvar my-tree-sitter-rust-src (expand-file-name "vendor/tree-sitter/tree-sitter-rust" my-init-dir))
(defvar my-tree-sitter-rust-repo "https://github.com/tree-sitter/tree-sitter-rust.git")
(when (not (file-directory-p my-tree-sitter-rust-src))
  (call-process "git" nil nil nil "clone" "--depth=1" my-tree-sitter-rust-repo my-tree-sitter-rust-src)
  )

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
  )

(provide 'my-tree-sitter)
