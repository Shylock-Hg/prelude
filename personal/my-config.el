;;; -*- lexical-binding: t -*-

(set-face-attribute 'default nil :font "JetBrains Mono-20")

(with-eval-after-load 'transient
  (add-hook 'transient-setup-buffer-hook (lambda ()
                                           (buffer-face-set '(:family "JetBrains Mono" :height 100))
                                           )
    )
)

;;(with-eval-after-load 'transient
  ;;(set-face-attribute 'transient-key nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-key-stay nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-key-exit nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-key-noop nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-key-stack nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-key-return nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-nonstandard-key nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-mismatched-key nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-key-recurse nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-active-infix nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-heading nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-value nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-argument nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-inactive-argument nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-delimiter nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-higher-level nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-inapt-suffix nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-inapt-argument nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-unreachable nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-enabled-suffix nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-inactive-value nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-disabled-suffix nil :font "JetBrains Mono-12")
  ;;(set-face-attribute 'transient-unreachable-key nil :font "JetBrains Mono-12")
  ;;)

;; auto run emacs server
(require 'server)
(unless (server-running-p)
  (server-start))


;; key bind emacs command
(defvar my-extended-command-key "C-,"
  "Keybinding for `execute-extended-command'.")
(global-set-key (kbd my-extended-command-key) 'execute-extended-command)
(with-eval-after-load 'flyspell
  (define-key flyspell-mode-map (kbd my-extended-command-key) nil)
  )

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
