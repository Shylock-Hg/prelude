;;; -*- lexical-binding: t -*-

(use-package modus-themes
  :ensure t
  :demand t
  :init
  ;; Prelude loads this theme after the personal preload configuration.
  (setq prelude-theme 'modus-operandi)
  :bind
  (("<f5>" . modus-themes-rotate)
   ("C-<f5>" . modus-themes-select)
   ("M-<f5>" . modus-themes-load-random))
  :config
  (setq modus-themes-mixed-fonts t)
  (setq modus-themes-italic-constructs t))

(provide 'my-theme-modus-operandi)
