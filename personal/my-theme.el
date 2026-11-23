;;; my-theme.el --- Personal theme configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Configure Ef before Prelude enables its theme and loads its modules.

;;; Code:

;; A preload file can still choose a different theme or set this to nil.
(defvar prelude-theme (quote ef-melissa-light))

(use-package ef-themes
  :ensure t
  :demand t
  :bind
  (("<f5>" . ef-themes-rotate)
   ("C-<f5>" . ef-themes-select)
   ("M-<f5>" . ef-themes-load-random))
  :config
  (setq modus-themes-mixed-fonts t)
  (setq modus-themes-italic-constructs t))

(provide 'my-theme)
;;; my-theme.el ends here
