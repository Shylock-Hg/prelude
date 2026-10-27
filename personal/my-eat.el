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

(defun my-eat--get-shell-history (original hist format)
  "Call ORIGINAL with HIST and FORMAT, guarding disabled shell history.
Eat 0.9.4 treats an empty history path as the current directory and attempts
to read it.  Acknowledge an empty or local directory path without reading it."
  (let* ((host (and (consp hist)
                    (ignore-errors (base64-decode-string (car hist)))))
         (file (and (consp hist)
                    (ignore-errors (base64-decode-string (cdr hist))))))
    (if (and file (or (string-empty-p file)
                      (and (equal host (system-name)) (file-directory-p file))))
        (eat-term-send-string eat-terminal "\e]51;e;I;0\e\\")
      (funcall original hist format))))

(advice-add 'eat--get-shell-history :around #'my-eat--get-shell-history)

(defvar my-eat-shell-init-directory
  (expand-file-name ".cache/eat-shell/" user-emacs-directory)
  "Directory for private Eat shell startup files.")

(defun my-eat--shell-init-file (name contents)
  "Write private startup file NAME with CONTENTS and return its path."
  (make-directory my-eat-shell-init-directory t)
  (let ((file (expand-file-name name my-eat-shell-init-directory)))
    ;; Another freshly launched shell may still be reading this file.
    (unless (and (file-readable-p file)
                 (equal contents (with-temp-buffer
                                   (insert-file-contents file)
                                   (buffer-string))))
      (with-temp-file file
        (insert contents)))
    file))

(defun my-eat--interactive-shell-args-p (name args)
  "Return non-nil for supported interactive NAME shell ARGS.
Use an allowlist so scripts, positional arguments, command runners and
options that disable startup files pass through without environment changes."
  (let ((supported t))
    (while (and args supported)
      (let ((arg (pop args)))
        (setq supported
              (if (equal name "bash")
                  (cond
                   ((member arg '("--rcfile" "--init-file"))
                    (and args (pop args) t))
                   ((member arg '("--norc" "--noprofile")) t)
                   (t (string-match-p "\\`-i+\\'" arg)))
                (or (member arg '("--login" "--interactive"))
                    (string-match-p "\\`-[il]+\\'" arg))))))
    supported))

(defun my-eat--prompt-refresh-script (shell)
  "Return SHELL code restoring Eat markers after prompt theme hooks.
Eat wraps prompts once during initialization.  Themes may replace them
before every prompt, so restore missing markers without wrapping twice."
  (if (equal shell "bash")
      "__prelude_eat_refresh_prompt () {
  local start='\\[\\e]51;e;B\\e\\\\\\]' end='\\[\\e]51;e;C\\e\\\\\\]'
  local cont_start='\\[\\e]51;e;D\\e\\\\\\]' cont_end='\\[\\e]51;e;E\\e\\\\\\]'
  case $PS1 in *\"$start\"*) ;; *) PS1=\"$start$PS1$end\";; esac
  case $PS2 in *\"$cont_start\"*) ;; *) PS2=\"$cont_start$PS2$cont_end\";; esac
}
PROMPT_COMMAND+=(__prelude_eat_refresh_prompt)
"
    "__prelude_eat_refresh_prompt () {
  local start=$(printf '%%{\\033]51;e;B\\033\\\\%%}')
  local end=$(printf '%%{\\033]51;e;C\\033\\\\%%}')
  local cont_start=$(printf '%%{\\033]51;e;D\\033\\\\%%}')
  local cont_end=$(printf '%%{\\033]51;e;E\\033\\\\%%}')
  case $PS1 in *\"$start\"*) ;; *) PS1=\"$start$PS1$end\";; esac
  case $PS2 in *\"$cont_start\"*) ;; *) PS2=\"$cont_start$PS2$cont_end\";; esac
}
add-zsh-hook precmd __prelude_eat_refresh_prompt
"))

(defun my-eat--edit-bindings-script (shell)
  "Return SHELL code configuring terminal editing.
Bash uses Emacs bindings so Evil can send conventional control keys.
Zsh keeps its editing mode and uses private native widget bindings."
  (if (equal shell "bash")
      ;; Run after the user's rc, which may select Readline's vi mode.
      "set -o emacs\n"
    "__prelude_eat_end_of_line () { zle .end-of-line; }
__prelude_eat_delete_char () { zle .delete-char; }
zle -N __prelude_eat_end_of_line
zle -N __prelude_eat_delete_char
for __prelude_eat_map in emacs viins; do
  bindkey -M \"$__prelude_eat_map\" '\\e[997~' __prelude_eat_end_of_line
  bindkey -M \"$__prelude_eat_map\" '\\e[998~' __prelude_eat_delete_char
done
unset __prelude_eat_map
_eat_msg prelude-edit-bindings
"))

(defun my-eat--integrated-shell (command)
  "Return COMMAND with automatic Bash or Zsh integration when supported.
Preserve user startup files.  Set launch-only variables in the caller's
private `process-environment'; never modify the user's shell files.
Arbitrary shell expressions, Bash login shells and command runners are passed
through and may configure Eat integration themselves."
  (let* ((words (split-string-and-unquote command))
         (shell (car words))
         (args (cdr words))
         (name (and shell (file-name-nondirectory shell))))
    (if (or (not (member name '("bash" "zsh")))
            (not (my-eat--interactive-shell-args-p name args)))
        command
      (pcase name
        ("bash"
         (let ((rc (expand-file-name ".bashrc" (getenv "HOME")))
               switches)
           (while args
             (let ((arg (pop args)))
               (cond
                ((equal arg "--norc") (setq rc ""))
                ((member arg '("--rcfile" "--init-file"))
                 (setq rc (or (pop args) "")))
                (t (push arg switches)))))
           (setenv "PRELUDE_EAT_BASHRC" rc)
           (let ((init (my-eat--shell-init-file
                        "bashrc"
                        (concat
                         "if [ -n \"$PRELUDE_EAT_BASHRC\" ] && [ -r \"$PRELUDE_EAT_BASHRC\" ]; then\n"
                         "  . \"$PRELUDE_EAT_BASHRC\"\nfi\nunset PRELUDE_EAT_BASHRC\n"
                         (my-eat--prompt-refresh-script "bash")
                         ". \"$EAT_SHELL_INTEGRATION_DIR/bash\"\n"
                         (my-eat--edit-bindings-script "bash")))))
             (mapconcat #'shell-quote-argument
                        (append (list shell "--rcfile" init)
                                (nreverse switches) '("-i")) " "))))
        ("zsh"
         (setenv "PRELUDE_EAT_ZDOTDIR" (or (getenv "ZDOTDIR") (getenv "HOME")))
         (setenv "PRELUDE_EAT_INIT_DIR" my-eat-shell-init-directory)
         (setenv "ZDOTDIR" my-eat-shell-init-directory)
         (dolist (file '(".zshenv" ".zprofile" ".zshrc" ".zlogin"))
           (my-eat--shell-init-file
            file
            (concat
             "ZDOTDIR=$PRELUDE_EAT_ZDOTDIR\n"
             "if [ -r \"$ZDOTDIR/" file "\" ]; then . \"$ZDOTDIR/" file "\"; fi\n"
             (let ((finish
                    (concat ". \"$EAT_SHELL_INTEGRATION_DIR/zsh\"\n"
                            (my-eat--prompt-refresh-script "zsh")
                            (my-eat--edit-bindings-script "zsh")
                            "unset PRELUDE_EAT_ZDOTDIR PRELUDE_EAT_INIT_DIR\n"))
                   (continue
                    (concat "export PRELUDE_EAT_ZDOTDIR=$ZDOTDIR\n"
                            "export ZDOTDIR=$PRELUDE_EAT_INIT_DIR\n")))
               (cond
                ((equal file ".zlogin") finish)
                ((equal file ".zshrc")
                 (concat "if [[ -o login ]]; then\n" continue
                         "else\n" finish "fi\n"))
                (t continue))))))
         (mapconcat #'shell-quote-argument (append words '("-i")) " "))))))

(defun my-eat--exec-with-integration (original buffer name command startfile switches)
  "Call ORIGINAL for BUFFER and NAME with automatic shell integration.
Preserve STARTFILE and arbitrary COMMAND/SWITCHES invocations.  This also
covers shells started through Eat's own entry points."
  (with-current-buffer (get-buffer-create buffer)
    (kill-local-variable 'my-eat--native-edit-bindings))
  (let ((process-environment (copy-sequence process-environment)))
    (if (and (equal (file-name-nondirectory command) "env")
             (equal (seq-take switches 2) '("sh" "-c"))
             (= (length switches) 3))
        (funcall original buffer name command startfile
                 (list "sh" "-c" (my-eat--integrated-shell (nth 2 switches))))
      (let* ((plain (mapconcat #'shell-quote-argument (cons command switches) " "))
             (integrated (my-eat--integrated-shell plain)))
        (if (equal plain integrated)
            (funcall original buffer name command startfile switches)
          (funcall original buffer name "/usr/bin/env" startfile
                   (list "sh" "-c" integrated)))))))

(advice-add 'eat-exec :around #'my-eat--exec-with-integration)

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

(defvar-local my-eat--native-edit-bindings nil
  "Non-nil when the shell has installed Prelude's native edit bindings.")

(defun my-eat--enable-native-edit-bindings ()
  "Record the shell's acknowledgement of its private edit bindings."
  (setq my-eat--native-edit-bindings t))

(add-to-list 'eat-message-handler-alist
             '("prelude-edit-bindings" . my-eat--enable-native-edit-bindings))

(defun my-eat--send-edit-key (operation)
  "Send native editing OPERATION, either `end' or `delete', to the shell.
Private keys bypass public widget wrappers and work in vi insertion mode.
Fall back to conventional control keys in shells without these bindings."
  (if my-eat--native-edit-bindings
      (eat-term-send-string eat-terminal
                            (if (eq operation 'end) "\e[997~" "\e[998~"))
    (eat-term-input-event eat-terminal 1
                          (if (eq operation 'end) ?\C-e ?\C-d))))

(defun my-eat--await-edit (prefix)
  "Wait until the shell cursor follows logical input PREFIX.
Only inspect text before the cursor: right prompts and suggestions after it
are display decorations, not part of the editable command.  Callers send
End first when they need to confirm the entire input."
  (let ((process (get-buffer-process (current-buffer)))
        (deadline (+ (float-time) 1.0)))
    (while
        (progn
          (when eat--pending-output-chunks
            (eat--process-output-queue (current-buffer)))
          (not (and (markerp my-eat--input-start)
                    (marker-position my-eat--input-start)
                    (<= my-eat--input-start
                        (eat-term-display-cursor eat-terminal))
                    (equal prefix
                           (my-eat--text
                            my-eat--input-start
                            (eat-term-display-cursor eat-terminal))))))
      (unless (and (process-live-p process) (< (float-time) deadline))
        (my-eat--forget-input-start)
        (user-error "Eat did not confirm the terminal edit; wait for shell output"))
      (accept-process-output process 0.01))))

(defun my-eat--input-text ()
  "Ask the shell for its input end and return the editable command text.
Restore the original cursor after reading.  Using the shell cursor excludes
right prompts, suggestions and blank cells left behind by redisplay."
  (let ((prefix (my-eat--text my-eat--input-start
                              (eat-term-display-cursor eat-terminal))))
    (my-eat--send-edit-key 'end)
    (my-eat--drain-shell-output)
    (let ((input (my-eat--text my-eat--input-start
                               (eat-term-display-cursor eat-terminal))))
      (dotimes (_ (max 0 (- (length input) (length prefix))))
        (eat-term-input-event eat-terminal 1 'left))
      (my-eat--await-edit prefix)
      input)))

(defun my-eat--drain-shell-output ()
  "Drain queued terminal output and move point to the shell cursor."
  (let ((process (get-buffer-process (current-buffer)))
        (deadline (+ (float-time) 1.0)))
    (when (process-live-p process)
      (while
          (progn
            (when eat--pending-output-chunks
              (eat--process-output-queue (current-buffer)))
            (and (< (float-time) deadline)
                 (accept-process-output process (max 0.033 eat-maximum-latency)))))
      (when eat--pending-output-chunks
        (eat--process-output-queue (current-buffer))))
    (goto-char (eat-term-display-cursor eat-terminal))))

(defun my-eat--self-input (original n &optional event)
  "Send EVENT N times through ORIGINAL and drain the shell's response.
Process all queued output and wait for an idle output interval before
returning point to the terminal cursor.  This handles completion, history,
kill/yank and wrapping without predicting the shell's resulting input."
  (let ((synchronize (and (my-eat--terminal-editing-p)
                          (bound-and-true-p evil-insert-state-minor-mode))))
    (prog1 (funcall original n event)
      (when (and synchronize (my-eat--terminal-editing-p))
        (my-eat--drain-shell-output)))))

(defun my-eat--evil-append-line (original count &optional vcount)
  "Append COUNT times at the shell input end, or call ORIGINAL with VCOUNT.
Use the shell's End binding rather than rendered trailing display blanks."
  (if (not (my-eat--terminal-editing-p))
      (funcall original count vcount)
    (unless (my-eat--editable-position-p (eat-term-display-cursor eat-terminal))
      (user-error "Eat appending requires a known shell prompt"))
    (when vcount
      (user-error "Eat appending supports a single input line"))
    (my-eat--send-edit-key 'end)
    (my-eat--drain-shell-output)
    (evil-insert count)))

(advice-add 'eat-self-input :around #'my-eat--self-input)

(defun my-eat--move-terminal-cursor (position)
  "Send arrow keys to move the terminal cursor to editable POSITION."
  (unless (my-eat--editable-position-p position)
    (user-error "Eat editing requires shell integration and a position after the prompt"))
  (let* ((cursor (eat-term-display-cursor eat-terminal))
         (distance (* (if (< position cursor) -1 1)
                      (length (my-eat--text (min position cursor)
                                            (max position cursor)))))
         (prefix (my-eat--text my-eat--input-start position)))
    (dotimes (_ (abs distance))
      (eat-term-input-event eat-terminal 1
                            (if (< distance 0) 'left 'right)))
    (my-eat--await-edit prefix)))

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
           (end-offset (length (my-eat--text my-eat--input-start end)))
           (input (my-eat--input-text))
           (after (progn
                    (unless (<= end-offset (length input))
                      (user-error "Eat deletion extends beyond the shell input"))
                    (substring input end-offset))))
      (unless register
        (evil-set-register ?- text))
      (let ((evil-was-yanked-without-register nil))
        (evil-yank beg end type register yank-handler))
      (my-eat--move-terminal-cursor beg)
      (dotimes (_ (length text))
        (my-eat--send-edit-key 'delete))
      ;; Confirm the whole command at the shell's logical End, then
      ;; return to the deletion point for the next Evil command.
      (my-eat--send-edit-key 'end)
      ;; At the last character the pre-delete cursor already has the
      ;; expected offset.  Drain the response before accepting that prefix.
      (my-eat--drain-shell-output)
      (my-eat--await-edit (concat before after))
      (dotimes (_ (length after))
        (eat-term-input-event eat-terminal 1 'left))
      (my-eat--await-edit before)
      (goto-char (eat-term-display-cursor eat-terminal)))))

(with-eval-after-load 'evil
  (add-hook 'evil-insert-state-entry-hook #'my-eat--evil-insert-entry)
  (advice-add 'evil-delete :around #'my-eat--evil-delete)
  (advice-add 'evil-change :around #'my-eat--evil-change)
  (advice-add 'evil-append-line :around #'my-eat--evil-append-line)
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
