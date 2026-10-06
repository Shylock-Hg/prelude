;;; my-tla.el --- TLA+ tree-sitter and LSP support -*- lexical-binding: t -*-

;;; Commentary:

;; Configure TLA+ support: the `tla-ts-mode' major mode backed by the
;; `tlaplus' tree-sitter grammar for syntax highlighting, and Eglot with
;; `tla-sany-lsp' for LSP features.

;;; Code:

(require 'my-eglot)
(require 'my-tree-sitter)
(require 'my-vendor)

;; `tla-ts-mode' is not available from an ELPA archive, so vendor it from
;; GitHub.  It provides tree-sitter font-lock, indentation, imenu and
;; navigation for TLA+ and PlusCal, and maps `.tla' to `tla-ts-mode'.
(defvar my-tla-ts-mode-dir (my-vendor-dest "dsociative" "tla-ts-mode"))

(my-vendor-install-git "github.com" "dsociative" "tla-ts-mode")

(add-to-list 'load-path my-tla-ts-mode-dir)
(require 'tla-ts-mode)

(treesit-install-language-grammar 'tlaplus)

;; `tla-sany-lsp' is a TLA+ language server built on `tla2sany'.  Install it
;; from https://github.com/jimmy-zx/tla-sany-lsp (`pip install -e .'; tested
;; at commit a2eb46b) and put `tla2tools.jar' on `CLASSPATH'.  Use the v1.8.0
;; prerelease jar, which provides `tla2sany.output.OutErrSanyOutput'; the
;; stable v1.7.4 jar lacks it and the server aborts before the LSP handshake:
;; https://github.com/tlaplus/tlaplus/releases/download/v1.8.0/tla2tools.jar
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(tla-ts-mode . ("tla-sany-lsp"))))

(add-hook 'tla-ts-mode-hook #'eglot-ensure)

(provide 'my-tla)
;;; my-tla.el ends here
