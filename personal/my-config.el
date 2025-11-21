;;; -*- lexical-binding: t -*-

(set-face-attribute 'default nil :font "JetBrains Mono-20")


;; auto run emacs server
(require 'server)
(unless (server-running-p)
  (server-start))


;; key bindg emacs command
(global-set-key (kbd "C-i") 'execute-extended-command)

(with-eval-after-load 'company
  (setq company-tooltip-flip-when-above nil)
  )


(provide 'my-config)
