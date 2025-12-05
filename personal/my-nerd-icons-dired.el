;;; -*- lexical-binding: t -*-

(require 'straight)

(use-package nerd-icons-dired
  :straight t
  :hook
  (dired-mode . nerd-icons-dired-mode))

(provide 'my-nerd-icons-dired)
