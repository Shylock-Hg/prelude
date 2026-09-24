;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-packages '(vterm vterm-toggle multi-vterm))

(require 'vterm)
(setq vterm-max-scrollback 10000)

(defvar-local my-vterm--extended-command-source-buffer nil
  "Vterm buffer whose point is preserved during this M-x prompt.")

(defun my-vterm--remember-extended-command-source-buffer ()
  "Remember the selected vterm buffer for an extended-command prompt."
  (setq-local my-vterm--extended-command-source-buffer nil)
  (when (eq this-command 'execute-extended-command)
    (let* ((window (minibuffer-selected-window))
           (buffer (and (window-live-p window)
                        (window-buffer window))))
      (when (and (buffer-live-p buffer)
                 (with-current-buffer buffer
                   (derived-mode-p 'vterm-mode)))
        (setq-local my-vterm--extended-command-source-buffer buffer)))))

(add-hook 'minibuffer-setup-hook
          #'my-vterm--remember-extended-command-source-buffer)

(defun my-vterm--clear-extended-command-source-buffer ()
  "Clear the saved vterm buffer after the M-x minibuffer closes."
  (setq-local my-vterm--extended-command-source-buffer nil))

(add-hook 'minibuffer-exit-hook
          #'my-vterm--clear-extended-command-source-buffer)

(defun my-vterm--preserve-point-during-extended-command
  (original buffer &rest args)
  "Preserve BUFFER's point during redraw while its M-x prompt is active."
  (let* ((window (active-minibuffer-window))
         (minibuffer (and (window-live-p window) (window-buffer window)))
         (source-buffer
          (and (buffer-live-p minibuffer)
               (buffer-local-value
                'my-vterm--extended-command-source-buffer minibuffer))))
    (let* ((protect (and (eq buffer source-buffer)
                         (buffer-live-p buffer)
                         (with-current-buffer buffer
                           (derived-mode-p 'vterm-mode))))
           (window-points
            (when protect
              (mapcar (lambda (window)
                        (cons window (window-point window)))
                      (get-buffer-window-list buffer nil t)))))
      (unwind-protect
          (if protect
              (with-current-buffer buffer
                (save-mark-and-excursion
                  (apply original buffer args)))
            (apply original buffer args))
        (dolist (entry window-points)
          (let ((window (car entry))
                (position (cdr entry)))
            (when (and (window-live-p window)
                       (eq (window-buffer window) buffer))
              (set-window-point
               window (min position
                           (with-current-buffer buffer (point-max)))))))))))

(advice-add 'vterm--delayed-redraw :around
            #'my-vterm--preserve-point-during-extended-command)

(use-package vterm-toggle
  :ensure t  ; Install if not present (requires use-package)
  :demand t
  :after vterm
  :config
  (setq vterm-toggle-cd-auto-create-buffer nil)  ; Reuse existing vterm even if no prompt found
  (setq vterm-toggle-use-dedicated-buffer nil)   ; Avoid dedicated buffers; share one globally
  (setq vterm-toggle-scope nil)              ; Force global scope to reuse across projects
  )

(defvar my-vterm-toggle-key "C-t" "My keybinding of vterm-toggle")
;; Let EVERY key go to the shell (disable all normal vterm stealing)
(advice-add 'vterm--exclude-keys :override #'ignore)
(setq vterm-keymap-exceptions nil)   ; ← this is the key line!
;; Only steal key for yourself
(add-hook 'vterm-mode-hook
          (lambda ()
            (keymap-local-unset my-vterm-toggle-key)
            (keymap-local-set my-vterm-toggle-key #'vterm-toggle)))   ; ← replace with whatever you want

(with-eval-after-load 'evil
  (define-key evil-normal-state-map (kbd my-vterm-toggle-key) #'vterm-toggle)
          )
(with-eval-after-load 'elisp-slime-nav
  (define-key (lookup-key elisp-slime-nav-mode-map [normal-state])
                  (kbd my-vterm-toggle-key)
                  #'vterm-toggle))
(with-eval-after-load 'eglot
  (define-key (lookup-key eglot-mode-map [normal-state])
                  (kbd my-vterm-toggle-key)
                  #'vterm-toggle))
(with-eval-after-load 'anaconda-mode
  (define-key (lookup-key anaconda-mode-map [normal-state])
                  (kbd my-vterm-toggle-key)
                  #'vterm-toggle))

;; multivterm
(defun multi-vterm-name (name)
  "Create a new vterm buffer named NAME and switch to it."
  (interactive "sNew vterm name: ")
  (let* ((vterm-buffer
          (generate-new-buffer (multi-vterm-format-buffer-name name))))
    (setq multi-vterm-buffer-list
          (nconc multi-vterm-buffer-list (list vterm-buffer)))
    (with-current-buffer vterm-buffer
      (vterm-mode)
      (multi-vterm-internal))
    (switch-to-buffer vterm-buffer)))

(use-package multi-vterm
        :ensure t
	:config
	(evil-define-key 'normal vterm-mode-map (kbd ",c")       #'multi-vterm)
	(evil-define-key 'normal vterm-mode-map (kbd ",n")       #'multi-vterm-next)
	(evil-define-key 'normal vterm-mode-map (kbd ",p")       #'multi-vterm-prev)
        )

(provide 'my-vterm)
