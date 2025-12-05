;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-packages '(treemacs treemacs-evil
                            treemacs-persp treemacs-projectile nerd-icons treemacs-nerd-icons))

(use-package nerd-icons
  :ensure t
  :demand t
  )
(use-package treemacs-nerd-icons
  :after nerd-icons
  :ensure t
  :demand t
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
