;;; my-theme.el --- Personal theme configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Configure Modus before Prelude enables its theme and loads its modules.

;;; Code:

;; A preload file can still choose a different theme or set this to nil.
(defvar prelude-theme 'modus-operandi)

(use-package modus-themes
  :ensure t
  :demand t
  :bind
  (("<f5>" . modus-themes-rotate)
   ("C-<f5>" . modus-themes-select)
   ("M-<f5>" . modus-themes-load-random))
  :config
  (setq modus-themes-mixed-fonts t)
  (setq modus-themes-italic-constructs t))

(provide 'my-theme)
;;; my-theme.el ends here
