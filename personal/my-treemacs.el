;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-packages '(treemacs treemacs-evil
                            treemacs-icons-dired treemacs-persp treemacs-projectile))

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
