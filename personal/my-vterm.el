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

(use-package vterm-toggle
  :ensure t  ; Install if not present (requires use-package)
  :config
  (setq vterm-toggle-cd-auto-create-buffer nil)  ; Reuse existing vterm even if no prompt found
  (setq vterm-toggle-use-dedicated-buffer nil)   ; Avoid dedicated buffers; share one globally
  (setq vterm-toggle-scope 'global)              ; Force global scope to reuse across projects
  :bind (my-vterm-toggle-key . vterm-toggle))  ; Example keybinding

(provide 'my-vterm)
