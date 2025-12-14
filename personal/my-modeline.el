;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'doom-modeline)

;; requrie run nerd-icons-install-fonts
(use-package doom-modeline
  :ensure t
  :hook (after-init . doom-modeline-mode)
  )

(provide 'my-modeline)
