;;; -*- lexical-binding: t -*-

(require 'my-eglot)
(require 'rust-mode)

(add-hook 'rust-mode-hook 'eglot-ensure)
(setq eglot-autoshutdown t)
(setq company-idle-delay 0.1)
(add-hook 'eglot-managed-mode-hook 'eglot-inlay-hints-mode)
(add-hook 'eglot-managed-mode-hook 'flymake-mode)

(provide 'my-lsp-rust)
