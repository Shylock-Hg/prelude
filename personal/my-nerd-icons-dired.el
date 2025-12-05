;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'nerd-icons-dired)

(use-package nerd-icons-dired
  :ensure t
  :after nerd-icons
  :hook
  (dired-mode . nerd-icons-dired-mode))

(provide 'my-nerd-icons-dired)
