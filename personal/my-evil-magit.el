;;; -*- lexical-binding: t -*-

(require 'prelude-packages)
(require 'prelude-evil)

(prelude-require-package 'evil-collection)

(use-package evil-collection
  :after evil
  :ensure t
  :demand t
  :config
  (evil-collection-init))

(provide 'my-evil-magit) 
