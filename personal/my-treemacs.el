;;; -*- lexical-binding: t -*-

(require 'prelude-packages)
(require 'straight)

(prelude-require-packages '(treemacs treemacs-evil
                            treemacs-persp treemacs-projectile))

(use-package nerd-icons
  :straight t
)
(use-package treemacs-nerd-icons
  :straight t
  :config
  (treemacs-nerd-icons-config))

;; Enable all follow modes (so Treemacs always shows current file/project)
(setq-default treemacs-follow-mode t
              treemacs-tag-follow-mode t
              treemacs-project-follow-mode t
              treemacs-width 25)
;; enable treemacs by default
(with-eval-after-load 'treemacs
  ;;(message "DEBUG POINT: %s" treemacs-persist-file)
  (treemacs)
  )

(require 'treemacs)

(provide 'my-treemacs)
