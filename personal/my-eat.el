;;; my-eat.el --- Eat terminal emulator configuration -*- lexical-binding: t -*-

;;; Commentary:

;; Terminal emulator configuration built around Eat
;; (https://codeberg.org/akib/emacs-eat).  This replaces the previous
;; vterm/vterm-toggle/multi-vterm setup.  `my-eat-toggle' shows or hides
;; the default terminal, while `my-eat-new', `my-eat-next' and
;; `my-eat-prev' manage several terminal sessions.

;;; Code:

(require 'prelude-packages)
(require 'seq)

(prelude-require-package 'eat)
(require 'eat)

(declare-function evil-define-key "evil-core")
(declare-function evil-set-initial-state "evil-core")
(defvar evil-normal-state-map)

(defvar my-eat-toggle-key "C-t"
  "My keybinding for toggling the Eat terminal.")

;; Reserve the toggle key for Emacs so it is not sent to the shell while
;; Eat is in its default \"semi-char\" input mode.
(add-to-list 'eat-semi-char-non-bound-keys (vconcat (kbd my-eat-toggle-key)))
(eat-update-semi-char-mode-map)

(defun my-eat--buffers ()
  "Return the live Eat terminal buffers, ordered by buffer name."
  (seq-sort-by #'buffer-name #'string<
               (seq-filter (lambda (buffer)
                             (with-current-buffer buffer
                               (derived-mode-p 'eat-mode)))
                           (buffer-list))))

(defun my-eat--shell ()
  "Return the shell program to run in a new Eat terminal.
Older Eat releases (for example the NonGNU ELPA 0.9.4 package) do not
define `eat-default-shell-function', so fall back to the same defaults
Eat itself uses."
  (cond
   ((and (boundp 'eat-default-shell-function)
         (functionp (symbol-value 'eat-default-shell-function)))
    (funcall (symbol-value 'eat-default-shell-function)))
   ((and (boundp 'eat-shell)
         (stringp (symbol-value 'eat-shell)))
    (symbol-value 'eat-shell))
   (t
    (or explicit-shell-file-name
        (getenv "ESHELL")
        shell-file-name))))

(defun my-eat--ensure-process (buffer)
  "Start an Eat shell in BUFFER unless it already runs one."
  (with-current-buffer buffer
    (unless (and (derived-mode-p 'eat-mode)
                 eat-terminal
                 (eat-term-parameter eat-terminal 'eat--process))
      (eat-mode)
      (eat-exec buffer (buffer-name) "/usr/bin/env" nil
                (list "sh" "-c" (my-eat--shell))))))

(defun my-eat-toggle ()
  "Toggle the default Eat terminal.
Show it in a window at the bottom of the frame, or hide its window
when it is already visible.  The terminal process keeps running
while hidden."
  (interactive)
  (let ((window (get-buffer-window eat-buffer-name (selected-frame))))
    (cond
     (window
      (if (window-parent window)
          (delete-window window)
        (bury-buffer (window-buffer window))))
     ((derived-mode-p 'eat-mode)
      (bury-buffer))
     (t
      (let ((buffer (get-buffer-create eat-buffer-name)))
        (my-eat--ensure-process buffer)
        (pop-to-buffer buffer
                       '(display-buffer-at-bottom
                         (window-height . 0.35))))))))

(defun my-eat--cycle (step)
  "Switch to the Eat terminal STEP positions away in the session list."
  (let ((buffers (my-eat--buffers)))
    (unless buffers
      (user-error "No Eat terminal is running; run `my-eat-toggle' first"))
    (let* ((position (seq-position buffers (current-buffer)))
           (target (if position
                       (nth (mod (+ position step) (length buffers)) buffers)
                     (if (> step 0)
                         (car buffers)
                       (car (last buffers))))))
      (pop-to-buffer target))))

(defun my-eat-next ()
  "Switch to the next Eat terminal session."
  (interactive)
  (my-eat--cycle 1))

(defun my-eat-prev ()
  "Switch to the previous Eat terminal session."
  (interactive)
  (my-eat--cycle -1))

(defun my-eat-new ()
  "Start a new Eat terminal session."
  (interactive)
  (let ((buffer (generate-new-buffer eat-buffer-name)))
    (my-eat--ensure-process buffer)
    (pop-to-buffer buffer)))

(define-key eat-mode-map (kbd my-eat-toggle-key) #'my-eat-toggle)

;; Reuse evil-collection's Eat integration when it is available.  The
;; package is loaded by `evil-collection-init' before this file, so eat is
;; initialized explicitly here.
(with-eval-after-load 'evil-collection
  (require 'evil-collection-eat nil t)
  (when (fboundp 'evil-collection-eat-setup)
    (evil-collection-eat-setup)))

(with-eval-after-load 'evil
  (evil-set-initial-state 'eat-mode 'insert)
  (define-key evil-normal-state-map (kbd my-eat-toggle-key) #'my-eat-toggle)
  (evil-define-key 'insert eat-mode-map
    (kbd my-eat-toggle-key) #'my-eat-toggle)
  (evil-define-key 'normal eat-mode-map
    (kbd ",c") #'my-eat-new
    (kbd ",n") #'my-eat-next
    (kbd ",p") #'my-eat-prev))

(provide 'my-eat)
;;; my-eat.el ends here
