;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

;; Emacs shows this buffer while confirming exit with active processes.
;; Keep it in its own bottom side window so displaying and quitting it
;; cannot split or reuse Treemacs's left side window.
(add-to-list 'display-buffer-alist
             '("\\`\\*Process List\\*\\'"
               (display-buffer-in-side-window)
               (side . bottom)
               (slot . 0)))

(prelude-require-packages '(treemacs treemacs-evil
                            treemacs-persp treemacs-projectile
                            nerd-icons treemacs-nerd-icons
                            treemacs-magit))


;; Enable all follow modes (so Treemacs always shows current file/project)
(use-package treemacs
  :ensure t
  :config
  (setq treemacs-follow-mode t
        treemacs-tag-follow-mode t
        treemacs-project-follow-mode t
        treemacs-width 25)
)

(use-package nerd-icons
  :ensure t
  :demand t
  )
(use-package treemacs-nerd-icons
  :after (nerd-icons treemacs)
  :ensure t
  :demand t
  :config
  (treemacs-nerd-icons-config))

(use-package treemacs-evil
  :after (treemacs evil)
  :ensure t)

(use-package treemacs-projectile
  :after (treemacs projectile)
  :ensure t)

(use-package treemacs-magit
  :after (treemacs magit)
  :ensure t
  :config
  ;; Avoid git-commit's synchronous HEAD polling after closing the editor.
  ;; Treemacs still refreshes through magit-post-commit-hook.
  (remove-hook 'git-commit-post-finish-hook
               #'treemacs-magit--schedule-update))

;;(use-package treemacs-persp ;;treemacs-perspective if you use perspective.el vs. persp-mode
  ;;:after (treemacs persp-mode) ;;or perspective vs. persp-mode
  ;;:ensure t
  ;;:config (treemacs-set-scope-type 'Perspectives))

(unless noninteractive
  (treemacs-start-on-boot))

(provide 'my-treemacs)
