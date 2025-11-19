;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'vterm)

(defvar my-vterm-toggle-key (kbd "C-`") "My keybinding of vterm-toggle")
(global-set-key my-vterm-toggle-key 'vterm-toggle)
;; Let EVERY key go to the shell (disable all normal vterm stealing)
(advice-add 'vterm--exclude-keys :override #'ignore)
(setq vterm-keymap-exceptions nil)   ; ← this is the key line!
;; Only steal C-` for yourself
(add-hook 'vterm-mode-hook
          (lambda ()
            (local-set-key my-vterm-toggle-key #'vterm-toggle)))   ; ← replace with whatever you want

;;(setq vterm-toggle-scope 'bottom)
(use-package vterm-toggle
  :ensure t
  :custom
  (vterm-toggle-scope 'bottom)
  )

(provide 'my-vterm)
