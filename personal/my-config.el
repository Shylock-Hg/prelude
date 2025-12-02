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


(defun my-c-mode-common-defaults ()
  (setq c-default-style "gnu"
        c-basic-offset 2)
  (c-set-offset 'substatement-open 0))

(setq my-c-mode-common-hook 'my-c-mode-common-defaults)

;; this will affect all modes derived from cc-mode, like
;; java-mode, php-mode, etc
(add-hook 'c-mode-common-hook (lambda ()
                                (run-hooks 'my-c-mode-common-hook)) 100)

(provide 'my-config)
