;;; -*- lexical-binding: t -*-

(use-package nerd-icons-dired
  :ensure t
  :hook
  (dired-mode . nerd-icons-dired-mode))

(provide 'my-nerd-icons-dired)
