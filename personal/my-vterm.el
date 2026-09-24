;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-packages '(vterm vterm-toggle multi-vterm))

(require 'vterm)
(setq vterm-max-scrollback 10000)

(defun my-vterm--minibuffer-source-buffer ()
  "Return the buffer selected before the active minibuffer, if any.
Redraws triggered while a minibuffer is active must not move the
cursor of the buffer the minibuffer was invoked from."
  (let ((window (minibuffer-selected-window)))
    (and (window-live-p window)
         (window-buffer window))))

(defun my-vterm--preserve-point (buffer thunk)
  "Call THUNK preserving BUFFER's cursor while a minibuffer uses BUFFER.
Point, mark and every window showing BUFFER are restored, so
terminal redraws cannot yank the cursor to the buffer end while the
user interacts with a minibuffer."
  (let* ((protect (and (eq buffer (my-vterm--minibuffer-source-buffer))
                       (buffer-live-p buffer)
                       (with-current-buffer buffer
                         (derived-mode-p 'vterm-mode))))
         (point (and protect (with-current-buffer buffer (point))))
         (mark (and protect (with-current-buffer buffer (mark t))))
         (window-points
          (when protect
            (mapcar (lambda (window)
                      (cons window (window-point window)))
                    (get-buffer-window-list buffer nil t)))))
    (unwind-protect
        (if protect
            (with-current-buffer buffer
              (unwind-protect
                  (funcall thunk)
                (goto-char (min point (point-max)))
                (when mark
                  (set-marker (mark-marker) (min mark (point-max))))))
          (funcall thunk))
      (dolist (entry window-points)
        (let ((window (car entry))
              (position (cdr entry)))
          (when (and (window-live-p window)
                     (eq (window-buffer window) buffer))
            (set-window-point
             window (min position
                         (with-current-buffer buffer (point-max))))))))))

(defun my-vterm--preserve-point-in-redraw (original buffer &rest args)
  "Preserve BUFFER's cursor around `vterm--delayed-redraw'."
  (my-vterm--preserve-point
   buffer (lambda () (apply original buffer args))))

(defun my-vterm--preserve-point-in-window-adjust (original process windows)
  "Preserve the vterm cursor around a terminal window resize.
`vterm--window-adjust-process-window-size' resizes the terminal and
redraws it synchronously through the native module, which moves the
buffer point to the terminal cursor."
  (my-vterm--preserve-point
   (process-buffer process)
   (lambda () (funcall original process windows))))

(advice-add 'vterm--delayed-redraw :around
            #'my-vterm--preserve-point-in-redraw)
(advice-add 'vterm--window-adjust-process-window-size :around
            #'my-vterm--preserve-point-in-window-adjust)

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
