;;; -*- lexical-binding: t -*-

(set-face-attribute 'default nil :font "JetBrains Mono-20")


;; auto run emacs server
(require 'server)
(unless (server-running-p)
  (server-start))

(provide 'my-config)
