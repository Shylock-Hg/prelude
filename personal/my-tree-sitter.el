;;; -*- lexical-binding: t -*-

(require 'treesit)

(with-eval-after-load 'treesit
  (add-to-list 'treesit-language-source-alist
               '(typst "https://github.com/uben0/tree-sitter-typst"
                       "master"))
  (add-to-list 'treesit-language-source-alist
               '(cmake "https://github.com/uyha/tree-sitter-cmake"
                       "master"))
  )

(provide 'my-tree-sitter)
