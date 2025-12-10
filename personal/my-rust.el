;;; -*- lexical-binding: t -*-


(require 'prelude-programming)
(require 'prelude-packages)

(prelude-require-packages '(rust-mode
                            cargo
                            flycheck-rust
                            yasnippet
                            ron-mode))

(require 'my-eglot)
(require 'rust-mode)
(require 'my-tree-sitter)

(treesit-install-language-grammar 'rust)

;; You may need to install the following packages on your system:
;; * rustc (Rust Compiler)
;; * cargo (Rust Package Manager)
;; * rustfmt (Rust Tool for formatting code)
;; * rust-analyzer as lsp server needs to be in global path, see:
;; https://rust-analyzer.github.io/manual.html#rust-analyzer-language-server-binary

(add-to-list 'super-save-predicates
             (lambda () (not (eq major-mode 'rust-mode))))

(with-eval-after-load 'rust-mode
  (add-hook 'rust-mode-hook 'cargo-minor-mode)
  (add-hook 'flycheck-mode-hook 'flycheck-rust-setup)

  (add-hook 'rust-mode-hook 'eglot-ensure)

  (defun prelude-rust-mode-defaults ()
    (setq rust-mode-treesitter-derive t)

    ;; format on save
    (setq rust-format-on-save t)

    ;; Prevent #! from chmodding rust files to be executable
    (remove-hook 'after-save-hook 'executable-make-buffer-file-executable-if-script-p)

    ;; snippets are required for correct lsp autocompletions
    (yas-minor-mode)

    ;; CamelCase aware editing operations
    (subword-mode +1))

  (setq prelude-rust-mode-hook 'prelude-rust-mode-defaults)

  (add-hook 'rust-mode-hook (lambda ()
                              (run-hooks 'prelude-rust-mode-hook))))

(setq eglot-autoshutdown t)
(setq company-idle-delay 0.1)
(add-hook 'eglot-managed-mode-hook 'eglot-inlay-hints-mode)
(add-hook 'eglot-managed-mode-hook 'flymake-mode)

(provide 'my-rust)
