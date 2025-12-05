;;; -*- lexical-binding: t -*-

(require 'straight)

;; don't enable :ensure when use straight.el
(use-package evil-collection
  :straight t
  :after evil
  :config
  (evil-collection-init))

(provide 'my-evil-magit)
