;;; -*- lexical-binding: t -*-

(require 'my-eglot)

(add-to-list 'eglot-server-programs
             '((c-mode c++-mode c-ts-mode c++-ts-mode) . ("clangd")))
(add-hook 'c-mode-hook #'eglot-ensure)
(add-hook 'c++-mode-hook #'eglot-ensure)

(provide 'my-lsp-clangd)
