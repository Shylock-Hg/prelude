;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'typst-ts-mode)

(require 'my-eglot)

;; require tinymist typst-lsp in PATH

;; tinymist
(with-eval-after-load 'eglot
  (with-eval-after-load 'typst-ts-mode
    (add-to-list 'eglot-server-programs
                  `((typst-ts-mode) .
                    ,(eglot-alternatives `(,typst-ts-lsp-download-path
                                          "tinymist"
                                          "typst-lsp"))))))

(provide 'my-typst)
