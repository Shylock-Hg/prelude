;;; -*- lexical-binding: t -*-

(prelude-require-packages '(treemacs-evil
                            treemacs-icons-dired treemacs-persp treemacs-projectile))

;; Enable all follow modes (so Treemacs always shows current file/project)
(setq-default treemacs-follow-mode t
              treemacs-tag-follow-mode t
              treemacs-project-follow-mode t
              treemacs-width 25)
;; enable treemacs by default
(when (fboundp 'treemacs)
  (treemacs)
  )

(provide 'my-treemacs)
