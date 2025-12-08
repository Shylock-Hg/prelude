;;; -*- lexical-binding: t -*-

(require 'treesit)

(with-eval-after-load 'treesit
  (add-to-list 'treesit-language-source-alist
               '(typst "https://github.com/uben0/tree-sitter-typst"
                       "master")))

(provide 'my-tree-sitter)
