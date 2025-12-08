;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'typst-ts-mode)

(require 'my-eglot)
(require 'my-tree-sitter)

;; require tinymist typst-lsp in PATH

(treesit-install-language-grammar 'typst)

;; tinymist
(with-eval-after-load 'eglot
  (with-eval-after-load 'typst-ts-mode
    (add-to-list 'eglot-server-programs
                  `((typst-ts-mode) .
                    ,(eglot-alternatives `(,typst-ts-lsp-download-path
                                          "tinymist"
                                          "typst-lsp"))))))

(add-hook 'typst-ts-mode-hook #'eglot-ensure)

(provide 'my-typst)
