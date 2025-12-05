;;; -*- lexical-binding: t -*-

(require 'prelude-packages)
(require 'prelude-evil)

;; There will be installation issue if install package by use-package
;; Maybe caused by mixing prelude and use-package installation methods
(prelude-require-package 'evil-collection)

(use-package evil-collection
  :after evil
  :ensure t
  :demand t
  :config
  (evil-collection-init))

(provide 'my-evil-magit)
