;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'ai-code)

(use-package ai-code
  :config
  ;; use codex as backend, other options are 'claude-code, 'gemini, 'github-copilot-cli, 'opencode, 'grok, 'cursor, 'kiro, 'claude-code-ide, 'claude-code-el
  (ai-code-set-backend 'opencode)
  ;; Enable global keybinding for the main menu
  ;; (global-set-key (kbd "C-c a") #'ai-code-menu)
  ;; Optional: Use eat if you prefer, by default it is vterm
  ;; (setq ai-code-backends-infra-terminal-backend 'eat) ;; for openai codex, github copilot cli, opencode, grok, cursor-cli; for claude-code-ide.el, you can check their config
  ;; Optional: Turn on auto-revert buffer, so that the AI code change automatically appears in the buffer
  (global-auto-revert-mode 1)
  (setq auto-revert-interval 1) ;; set to 1 second for faster update
  ;; Optional: Set up Magit integration for AI commands in Magit popups
  (with-eval-after-load 'magit
    (ai-code-magit-setup-transients)))

(provide 'my-ai-code)
