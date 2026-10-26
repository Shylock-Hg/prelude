;;; my-eat.el --- Eat terminal emulator configuration -*- lexical-binding: t -*-

;;; Commentary:

;; Terminal emulator configuration built around Eat
;; (https://codeberg.org/akib/emacs-eat).  This replaces the previous
;; vterm/vterm-toggle/multi-vterm setup.  `my/eat-toggle' shows or hides
;; the default terminal, while `my/eat-new', `my/eat-next' and
;; `my/eat-prev' manage several terminal sessions.

;;; Code:

(require 'prelude-packages)
(require 'seq)

(prelude-require-package 'eat)
(require 'eat)

;; ncurses `clear' sends E3 (CSI 3 J) when the terminal advertises it.
;; Eat understands that sequence, but its bundled terminfo omits E3.
;; Compile a private copy so only programs running in Eat see it.
(defvar my-eat-terminfo-directory
  (expand-file-name ".cache/eat-terminfo/" user-emacs-directory)
  "Private terminfo directory for Eat terminals.")

(defun my-eat--terminfo-source ()
  "Return Eat's bundled terminfo source, or signal an error."
  (let ((source (expand-file-name "eat.ti"
                                  (file-name-directory (locate-library "eat")))))
    (unless (file-readable-p source)
      (error "Cannot read Eat terminfo source: %s" source))
    source))

(defun my-eat--terminfo-with-e3 (source)
  "Return SOURCE with the E3 capability added to Eat's base entry."
  (with-temp-buffer
    (insert-file-contents source)
    (goto-char (point-min))
    (unless (re-search-forward "^[ \t]*clear=[^,\n]*," nil t)
      (error "Eat terminfo has no clear capability: %s" source))
    (let ((clear-end (point)))
      (goto-char (point-min))
      (unless (re-search-forward "^[ \t]*E3=" nil t)
        (goto-char clear-end)
        (insert "\n  E3=\\E[3J,")))
    (buffer-string)))

(defun my-eat--configure-terminfo ()
  "Compile Eat terminfo with E3 and use it for Eat subprocesses."
  (let* ((source (my-eat--terminfo-source))
         (generated (expand-file-name "eat-with-e3.ti"
                                      my-eat-terminfo-directory))
         (contents (my-eat--terminfo-with-e3 source))
         (entries '("eat-mono" "eat-color" "eat-256color" "eat-truecolor"))
         (outdated
          (or (not (file-exists-p generated))
              (not (string= contents
                            (with-temp-buffer
                              (insert-file-contents generated)
                              (buffer-string))))
              (seq-some
               (lambda (name)
                 (let ((compiled (expand-file-name
                                  (concat "e/" name)
                                  my-eat-terminfo-directory)))
                   (or (not (file-exists-p compiled))
                       (file-newer-than-file-p generated compiled))))
               entries))))
    (when outdated
      (unless (executable-find "tic")
        (error "Cannot compile Eat terminfo: `tic' is not installed"))
      (make-directory my-eat-terminfo-directory t)
      (with-temp-file generated
        (insert contents))
      (with-current-buffer (get-buffer-create "*Eat terminfo build*")
        (erase-buffer)
        (unless (eq 0 (call-process "tic" nil t nil "-x" "-o"
                                    my-eat-terminfo-directory generated))
          (error "Cannot compile Eat terminfo; see *Eat terminfo build*"))))
    (setq eat-term-terminfo-directory my-eat-terminfo-directory)))

(my-eat--configure-terminfo)

(declare-function evil-define-key "evil-core")
(declare-function evil-get-auxiliary-keymap "evil-core")
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

(defun my/eat-toggle ()
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
      (user-error "No Eat terminal is running; run `my/eat-toggle' first"))
    (let* ((position (seq-position buffers (current-buffer)))
           (target (if position
                       (nth (mod (+ position step) (length buffers)) buffers)
                     (if (> step 0)
                         (car buffers)
                       (car (last buffers))))))
      (pop-to-buffer target))))

(defun my/eat-next ()
  "Switch to the next Eat terminal session."
  (interactive)
  (my-eat--cycle 1))

(defun my/eat-prev ()
  "Switch to the previous Eat terminal session."
  (interactive)
  (my-eat--cycle -1))

(defun my/eat-new ()
  "Start a new Eat terminal session."
  (interactive)
  (let ((buffer (generate-new-buffer eat-buffer-name)))
    (my-eat--ensure-process buffer)
    (pop-to-buffer buffer)))

(define-key eat-mode-map (kbd my-eat-toggle-key) #'my/eat-toggle)

;; Reuse evil-collection's Eat integration when it is available.  The
;; package is loaded by `evil-collection-init' before this file, so eat is
;; initialized explicitly here.
(with-eval-after-load 'evil-collection
  (require 'evil-collection-eat nil t)
  (when (fboundp 'evil-collection-eat-setup)
    (evil-collection-eat-setup)))

(defun my-eat--terminal-editing-p ()
  "Return non-nil when Evil edits a live Eat terminal directly."
  (and (derived-mode-p 'eat-mode) eat-terminal
       (or eat--semi-char-mode eat--char-mode)))

(defun my-eat--same-terminal-line-p (position)
  "Return non-nil if POSITION is on the terminal cursor's buffer line."
  (let ((cursor (eat-term-display-cursor eat-terminal)))
    (save-excursion
      (goto-char cursor)
      (<= (line-beginning-position) position (line-end-position)))))

(defvar-local my-eat--input-start nil
  "Marker at the editable input boundary reported by Eat shell integration.")

(defun my-eat--remember-input-start (&rest _ignored)
  "Record the shell integration's prompt end as the input boundary."
  (setq my-eat--input-start (copy-marker (point))))

(defun my-eat--forget-input-start (&rest _ignored)
  "Invalidate the input boundary when a command or a new prompt starts."
  (when (markerp my-eat--input-start)
    (set-marker my-eat--input-start nil)))

(advice-add 'eat--post-prompt :after #'my-eat--remember-input-start)
(advice-add 'eat--post-cont-prompt :after #'my-eat--remember-input-start)
(advice-add 'eat--pre-prompt :before #'my-eat--forget-input-start)
(advice-add 'eat--pre-cmd :before #'my-eat--forget-input-start)

(defun my-eat--editable-position-p (position)
  "Return non-nil when POSITION is a known editable terminal position."
  (and (markerp my-eat--input-start)
       (eq (marker-buffer my-eat--input-start) (current-buffer))
       (<= my-eat--input-start position)
       (my-eat--same-terminal-line-p position)))

(defun my-eat--text (beg end)
  "Return terminal text between BEG and END without hidden cell padding."
  (let ((inhibit-read-only t))
    (substring-no-properties
     (eat-term-filter-string (buffer-substring beg end)))))

(defun my-eat--await-edit (text offset)
  "Wait for logical input TEXT and character cursor OFFSET to be displayed.
Flush Eat's queued output so subsequent macro commands see the new cursor.
Signal an error after one second rather than allowing another stale edit."
  (let ((process (get-buffer-process (current-buffer)))
        (deadline (+ (float-time) 1.0)))
    (while
        (progn
          (when eat--pending-output-chunks
            (eat--process-output-queue (current-buffer)))
          (not (save-excursion
                 (goto-char (eat-term-display-cursor eat-terminal))
                 (and (markerp my-eat--input-start)
                      (marker-position my-eat--input-start)
                      ;; Readline may paint blanks after the logical input
                      ;; when deleting and reflowing wrapped terminal rows.
                      (equal (string-trim-right text " +")
                             (string-trim-right
                              (my-eat--text my-eat--input-start
                                            (eat-term-end eat-terminal)) " +"))
                      (= offset (length (my-eat--text
                                         my-eat--input-start (point))))))))
      (unless (and (process-live-p process) (< (float-time) deadline))
        (my-eat--forget-input-start)
        (user-error "Eat did not confirm the terminal edit; wait for shell output"))
      (accept-process-output process 0.01))))

(defun my-eat--self-input (original n &optional event)
  "Send EVENT N times through ORIGINAL and drain the shell's response.
Process all queued output and wait for an idle output interval before
returning point to the terminal cursor.  This handles completion, history,
kill/yank and wrapping without predicting the shell's resulting input."
  (let ((synchronize (and (my-eat--terminal-editing-p)
                          (bound-and-true-p evil-insert-state-minor-mode))))
    (prog1 (funcall original n event)
      (when (and synchronize (my-eat--terminal-editing-p))
        (let ((process (get-buffer-process (current-buffer)))
              (deadline (+ (float-time) 1.0)))
          (when (process-live-p process)
            (while
                (progn
                  (when eat--pending-output-chunks
                    (eat--process-output-queue (current-buffer)))
                  (and (< (float-time) deadline)
                       (accept-process-output
                        process (max 0.033 eat-maximum-latency)))))
            (when eat--pending-output-chunks
              (eat--process-output-queue (current-buffer))))
          (goto-char (eat-term-display-cursor eat-terminal)))))))

(advice-add 'eat-self-input :around #'my-eat--self-input)

(defun my-eat--move-terminal-cursor (position)
  "Send arrow keys to move the terminal cursor to editable POSITION."
  (unless (my-eat--editable-position-p position)
    (user-error "Eat editing requires shell integration and a position after the prompt"))
  (let* ((cursor (eat-term-display-cursor eat-terminal))
         (distance (* (if (< position cursor) -1 1)
                      (length (my-eat--text (min position cursor)
                                            (max position cursor)))))
         (text (my-eat--text my-eat--input-start (eat-term-end eat-terminal)))
         (offset (length (my-eat--text my-eat--input-start position))))
    (dotimes (_ (abs distance))
      (eat-term-input-event eat-terminal 1
                            (if (< distance 0) 'left 'right)))
    (my-eat--await-edit text offset)))

(defvar my-eat--changing nil
  "Non-nil while an Evil change operator already positions Eat's cursor.")

(defun my-eat--evil-change (original &rest arguments)
  "Call ORIGINAL with ARGUMENTS without aligning Eat twice."
  (let ((my-eat--changing (my-eat--terminal-editing-p)))
    (apply original arguments)))

(defun my-eat--evil-insert-entry ()
  "Align the shell cursor with Evil's insertion point in Eat.
When returning from scrollback, resume input at the terminal cursor."
  (when (and (my-eat--terminal-editing-p) (not my-eat--changing))
    (cond
     ((= (point) (eat-term-display-cursor eat-terminal)))
     ((my-eat--same-terminal-line-p (point))
      (my-eat--move-terminal-cursor (point)))
     (t (goto-char (eat-term-display-cursor eat-terminal))))))

(defun my-eat--evil-delete (original beg end type &optional register yank-handler)
  "Send Evil deletion from BEG to END to Eat, or call ORIGINAL.
TYPE, REGISTER and YANK-HANDLER retain their usual Evil meanings.
Only characterwise ranges on the current terminal line are supported."
  (if (not (my-eat--terminal-editing-p))
      (funcall original beg end type register yank-handler)
    ;; Eat puts invisible padding BEFORE a wide glyph.  An Evil motion may
    ;; start there; deleting that displayed character must include the glyph.
    (when (and (> end beg)
               (get-text-property beg 'eat--t-invisible-space))
      (setq beg (next-single-property-change
                 beg 'eat--t-invisible-space nil (point-max))
            end (max end (1+ beg))))
    (unless (and (memq type '(inclusive exclusive))
                 (my-eat--editable-position-p beg)
                 (my-eat--editable-position-p end))
      (user-error "Eat deletion requires a characterwise range after a known prompt"))
    (let* ((text (my-eat--text beg end))
           (before (my-eat--text my-eat--input-start beg))
           (after (my-eat--text end (eat-term-end eat-terminal))))
      (unless register
        (evil-set-register ?- text))
      (let ((evil-was-yanked-without-register nil))
        (evil-yank beg end type register yank-handler))
      (my-eat--move-terminal-cursor beg)
      (dotimes (_ (length text))
        (eat-term-input-event eat-terminal 1 'delete))
      (my-eat--await-edit (concat before after) (length before))
      (goto-char (eat-term-display-cursor eat-terminal)))))

(with-eval-after-load 'evil
  (add-hook 'evil-insert-state-entry-hook #'my-eat--evil-insert-entry)
  (advice-add 'evil-delete :around #'my-eat--evil-delete)
  (advice-add 'evil-change :around #'my-eat--evil-change)
  (evil-set-initial-state 'eat-mode 'insert)
  (define-key evil-normal-state-map (kbd my-eat-toggle-key) #'my/eat-toggle)
  (evil-define-key 'insert eat-mode-map
    (kbd my-eat-toggle-key) #'my/eat-toggle)
  (evil-define-key 'normal eat-mode-map
    (kbd ",c") #'my/eat-new
    (kbd ",n") #'my/eat-next
    (kbd ",p") #'my/eat-prev))

;; These minor modes install their own Evil normal-state maps.  In
;; particular, Evil Collection binds C-t to `pop-tag-mark' in
;; elisp-slime-nav, shadowing `evil-normal-state-map'.
(defun my-eat--bind-normal-toggle (map)
  "Bind the Eat toggle in the Evil normal-state part of MAP."
  (define-key (evil-get-auxiliary-keymap map 'normal t t)
              (kbd my-eat-toggle-key) #'my/eat-toggle))

(with-eval-after-load 'elisp-slime-nav
  (my-eat--bind-normal-toggle elisp-slime-nav-mode-map))
(with-eval-after-load 'eglot
  (my-eat--bind-normal-toggle eglot-mode-map))
(with-eval-after-load 'anaconda-mode
  (my-eat--bind-normal-toggle anaconda-mode-map))

(provide 'my-eat)
;;; my-eat.el ends here
