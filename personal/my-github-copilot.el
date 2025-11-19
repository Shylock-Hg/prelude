;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'copilot)

;; M-x copilot-install-server
;; M-x copilot-login
;; M-x copilot-mode to enable copilot

;; github copilot
(global-set-key (kbd "C-<return>") 'copilot-accept-completion)

;; It's unique for each buffer, so we enable it in prog-mode-hook
(add-hook 'prog-mode-hook 'copilot-mode)

(provide 'my-github-copilot)
