;;; -*- lexical-binding: t; -*-

;; Focused tests for the Eat terminal configuration in personal/my-eat.el.

(require 'ert)
(require 'seq)
(require 'evil)
(require 'eat)
(require 'my-eat)

;; Keep the real Evil state machine and its pre/post command hooks active.
(evil-mode 1)

(defvar my-eat-test-shadow-mode-map (make-sparse-keymap))
(define-minor-mode my-eat-test-shadow-mode
  "Minor mode used to test normal-state binding precedence."
  :keymap my-eat-test-shadow-mode-map)

(defconst my-eat-test--timeout 5.0
  "Seconds to wait for a terminal process to produce output.")

(defconst my-eat-test--bash-prompt
  (if (zerop (user-uid)) "# " "$ ")
  "Default Bash prompt suffix for the user running the tests.")

(defun my-eat-test--wait-for-text (buffer process text)
  "Wait up to `my-eat-test--timeout' for TEXT in BUFFER."
  (let ((deadline (+ (float-time) my-eat-test--timeout))
        found)
    (while (and (not found) (< (float-time) deadline))
      (with-current-buffer buffer
        (save-excursion
          (goto-char (point-min))
          (setq found (string-match-p
                       (regexp-quote text)
                       (let ((inhibit-read-only t))
                         (eat-term-filter-string (buffer-string)))))))
      (unless found
        (accept-process-output process 0.05)))
    found))

(defun my-eat-test--kill-terminal (name)
  "Kill the terminal buffer NAME and its process, if any."
  (let ((buffer (get-buffer name)))
    (when (buffer-live-p buffer)
      (let ((process (get-buffer-process buffer)))
        (when (process-live-p process)
          (delete-process process)))
      (kill-buffer buffer))))

(ert-deftest my-eat-provides-terminal-commands ()
  "The configuration exposes its terminal commands."
  (dolist (command '(my/eat-toggle my/eat-new my/eat-next my/eat-prev))
    (should (commandp command))))

(ert-deftest my-eat-clear-erases-scrollback ()
  "The private terminfo makes ncurses `clear' emit CSI 3 J."
  (should (equal my-eat-terminfo-directory
                 (expand-file-name ".cache/eat-terminfo/"
                                   user-emacs-directory)))
  (skip-unless (and (executable-find "tic")
                    (executable-find "infocmp")
                    (executable-find "clear")))
  (let ((directory (make-temp-file "my-eat-terminfo-" t))
        (original eat-term-terminfo-directory)
        (global-terminfo (getenv "TERMINFO")))
    (unwind-protect
        (let ((my-eat-terminfo-directory directory))
          (my-eat--configure-terminfo)
          (should (equal eat-term-terminfo-directory directory))
          (should (equal (getenv "TERMINFO") global-terminfo))
          (dolist (term '("eat-mono" "eat-color"
                          "eat-256color" "eat-truecolor"))
            (let ((process-environment
                   (cons (concat "TERMINFO=" directory)
                         (cons (concat "TERM=" term) process-environment))))
              (with-temp-buffer
                (should (= 0 (call-process "infocmp" nil t nil "-x" "-1")))
                (goto-char (point-min))
                (should (search-forward "E3=\\E[3J," nil t)))
              (with-temp-buffer
                (should (= 0 (call-process "clear" nil t)))
                (should (string-match-p (regexp-quote "\e[2J\e[3J")
                                        (buffer-string))))))
          (let ((compiled (expand-file-name "e/eat-truecolor" directory)))
            (delete-file compiled)
            (my-eat--configure-terminfo)
            (should (file-exists-p compiled))))
      (setq eat-term-terminfo-directory original)
      (delete-directory directory t))))

(ert-deftest my-eat-reserves-the-toggle-key ()
  "The toggle key is not swallowed by Eat and is bound to the toggle."
  (should (member (vconcat (kbd my-eat-toggle-key))
                  eat-semi-char-non-bound-keys))
  (should (eq (lookup-key eat-mode-map (kbd my-eat-toggle-key))
              #'my/eat-toggle)))

(ert-deftest my-eat-binds-evil-keys ()
  "The toggle and session keys are bound in Evil's normal/insert states."
  (should (eq (lookup-key evil-normal-state-map (kbd my-eat-toggle-key))
              #'my/eat-toggle))
  (with-temp-buffer
    (fundamental-mode)
    (evil-normal-state)
    (should (eq (key-binding (kbd my-eat-toggle-key)) #'my/eat-toggle))
    (evil-insert-state)
    (should-not (eq (key-binding (kbd my-eat-toggle-key)) #'my/eat-toggle)))
  (with-temp-buffer
    (eat-mode)
    (let ((normal (evil-get-auxiliary-keymap eat-mode-map 'normal t t))
          (insert (evil-get-auxiliary-keymap eat-mode-map 'insert t t)))
      (should (eq (lookup-key normal (kbd ",c")) #'my/eat-new))
      (should (eq (lookup-key normal (kbd ",n")) #'my/eat-next))
      (should (eq (lookup-key normal (kbd ",p")) #'my/eat-prev))
      (should (eq (lookup-key insert (kbd my-eat-toggle-key))
                  #'my/eat-toggle)))))

(ert-deftest my-eat-overrides-a-minor-mode-normal-binding ()
  "The toggle wins over a minor mode's Evil normal-state binding."
  (evil-define-key 'normal my-eat-test-shadow-mode-map
    (kbd my-eat-toggle-key) #'pop-tag-mark)
  (with-temp-buffer
    (fundamental-mode)
    (my-eat-test-shadow-mode 1)
    (evil-normal-state)
    (evil-normalize-keymaps)
    (should (eq (key-binding (kbd my-eat-toggle-key)) #'pop-tag-mark))
    (my-eat--bind-normal-toggle my-eat-test-shadow-mode-map)
    (should (eq (key-binding (kbd my-eat-toggle-key)) #'my/eat-toggle))))

(ert-deftest my-eat-toggle-starts-and-hides-a-terminal ()
  "`my/eat-toggle' shows a live terminal, then hides its window."
  (let ((eat-buffer-name "*my-eat-toggle-test*"))
    (unwind-protect
        (progn
          (my/eat-toggle)
          (should (derived-mode-p 'eat-mode))
          (should (get-buffer-window eat-buffer-name))
          (should (process-live-p (get-buffer-process eat-buffer-name)))
          (my/eat-toggle)
          (should-not (get-buffer-window eat-buffer-name))
          (should (buffer-live-p (get-buffer eat-buffer-name))))
      (my-eat-test--kill-terminal eat-buffer-name))))

(ert-deftest my-eat-new-creates-an-independent-session ()
  "`my/eat-new' starts a second terminal next to the default one."
  (let ((eat-buffer-name "*my-eat-new-test*"))
    (unwind-protect
        (progn
          (my/eat-toggle)
          (let ((first (get-buffer eat-buffer-name))
                (count (length (my-eat--buffers))))
            (my/eat-new)
            (should (derived-mode-p 'eat-mode))
            (should-not (eq (current-buffer) first))
            (should (= (length (my-eat--buffers)) (1+ count)))
            (should (process-live-p (get-buffer-process (current-buffer))))))
      (dolist (buffer (my-eat--buffers))
        (when (string-prefix-p eat-buffer-name (buffer-name buffer))
          (my-eat-test--kill-terminal (buffer-name buffer)))))))

(ert-deftest my-eat-new-without-default-shell-function ()
  "`my/eat-new' works with Eat releases lacking the default shell variable.
The NonGNU ELPA 0.9.4 package does not define
`eat-default-shell-function'."
  (let ((eat-buffer-name "*my-eat-no-default-shell-test*")
        (had-default (boundp 'eat-default-shell-function))
        (value (and (boundp 'eat-default-shell-function)
                    (symbol-value 'eat-default-shell-function)))
        buffer)
    (unwind-protect
        (progn
          (when had-default
            (makunbound 'eat-default-shell-function))
          (my/eat-new)
          (setq buffer (current-buffer))
          (should (derived-mode-p 'eat-mode))
          (should (process-live-p (get-buffer-process buffer))))
      (when had-default
        (set 'eat-default-shell-function value))
      (when (buffer-live-p buffer)
        (let ((process (get-buffer-process buffer)))
          (when (process-live-p process)
            (delete-process process)))
        (kill-buffer buffer)))))

(ert-deftest my-eat-next-and-prev-cycle-sessions ()
  "`my/eat-next' and `my/eat-prev' cycle through the live sessions."
  (let ((eat-buffer-name "*my-eat-cycle-test*"))
    (unwind-protect
        (progn
          (my/eat-toggle)
          (my/eat-new)
          (let* ((buffers (my-eat--buffers))
                 (first (car buffers))
                 (last (car (last buffers))))
            (pop-to-buffer first)
            (my/eat-next)
            (should-not (eq (current-buffer) first))
            (my/eat-prev)
            (should (eq (current-buffer) first))
            (my/eat-prev)
            (should (eq (current-buffer) last))))
      (dolist (buffer (my-eat--buffers))
        (when (string-prefix-p eat-buffer-name (buffer-name buffer))
          (my-eat-test--kill-terminal (buffer-name buffer)))))))

(ert-deftest my-eat-cycle-errors-without-a-terminal ()
  "Cycling without a running terminal signals a user error."
  (should-error (my/eat-next) :type 'user-error)
  (should-error (my/eat-prev) :type 'user-error))

(ert-deftest my-eat-runs-a-shell-command ()
  "A terminal started through the configuration really runs a shell."
  (let ((eat-buffer-name "*my-eat-shell-test*"))
    (unwind-protect
        (progn
          (my/eat-toggle)
          (let ((buffer (get-buffer eat-buffer-name)))
            (with-current-buffer buffer
              (goto-char (point-max))
              (eat-term-send-string eat-terminal "printf 'MYEAT_HELLO\n'")
              (eat-term-send-string eat-terminal "\r"))
            (should (my-eat-test--wait-for-text
                     buffer (get-buffer-process buffer) "MYEAT_HELLO"))))
      (my-eat-test--kill-terminal eat-buffer-name))))


(defun my-eat-test--enable-integration (process)
  "Enable Eat's Bash integration and wait for a known prompt from PROCESS."
  (eat-term-send-string
   eat-terminal "source \"$EAT_SHELL_INTEGRATION_DIR/bash\"\r")
  (let ((deadline (+ (float-time) my-eat-test--timeout)))
    (while (and (not (and (markerp my-eat--input-start)
                         (marker-position my-eat--input-start)))
                (< (float-time) deadline))
      (accept-process-output process 0.01)))
  (should (and (markerp my-eat--input-start)
               (marker-position my-eat--input-start))))

(ert-deftest my-eat-evil-edits-the-shell-input ()
  "Evil insertion and deletion change the command executed by a real shell."
  (skip-unless (executable-find "bash"))
  (let ((eat-buffer-name "*my-eat-edit-test*")
        (eat-shell "bash --noprofile --norc -i"))
    (unwind-protect
        (progn
          (my/eat-toggle)
          (let* ((buffer (current-buffer))
                 (process (get-buffer-process buffer)))
            (unless (my-eat-test--wait-for-text buffer process my-eat-test--bash-prompt)
              (ert-fail (buffer-string)))
            (my-eat-test--enable-integration process)
            (eat-term-send-string eat-terminal "printf 'RESULT:acXd\\n'")
            (should (my-eat-test--wait-for-text buffer process "RESULT:acXd"))
            (execute-kbd-macro (kbd "<escape>"))
            (goto-char (point-min))
            (search-forward "RESULT:a")
            (execute-kbd-macro (kbd "i b"))
            (should (my-eat-test--wait-for-text buffer process "RESULT:abcXd"))
            (execute-kbd-macro (kbd "<escape>"))
            (goto-char (point-min))
            (search-forward "RESULT:abc")
            (execute-kbd-macro (kbd "x"))
            (should (my-eat-test--wait-for-text buffer process "RESULT:abcd"))
            (execute-kbd-macro (kbd "<escape>"))
            (goto-char (point-min))
            (search-forward "RESULT:")
            (execute-kbd-macro (kbd "a Q"))
            (should (my-eat-test--wait-for-text buffer process "RESULT:aQbcd"))
            (execute-kbd-macro (kbd "<escape>"))
            (goto-char (point-min))
            (search-forward "RESULT:aQ")
            (execute-kbd-macro (kbd "X"))
            (should (my-eat-test--wait-for-text buffer process "RESULT:abcd"))
            (goto-char (point-min))
            (search-forward "RESULT:a")
            (execute-kbd-macro (kbd "2 x"))
            (should (my-eat-test--wait-for-text buffer process "RESULT:ad"))
            (goto-char (point-min))
            (search-forward "RESULT:a")
            (execute-kbd-macro (kbd "c l z"))
            (should (my-eat-test--wait-for-text buffer process "RESULT:az"))
            (execute-kbd-macro (kbd "<escape> A <return>"))
            (should (my-eat-test--wait-for-text buffer process "RESULT:az\n"))
            (should (string-match-p "\nRESULT:az\n" (buffer-string)))))
      (my-eat-test--kill-terminal eat-buffer-name))))

(ert-deftest my-eat-evil-delete-preserves-ordinary-buffers ()
  "Terminal deletion advice leaves ordinary Evil editing intact."
  (with-temp-buffer
    (insert "abcd")
    (evil-delete 2 4 'exclusive)
    (should (equal (buffer-string) "ad"))))

(ert-deftest my-eat-evil-delete-rejects-scrollback-and-linewise-ranges ()
  "Unsupported terminal deletions never change the terminal display."
  (with-temp-buffer
    (eat-mode)
    (setq eat-terminal (eat-term-make (current-buffer) (point-min)))
    (let ((inhibit-read-only t))
      (eat-term-process-output eat-terminal "old output\r\n$ input")
      (eat-term-redisplay eat-terminal))
    (eat-semi-char-mode)
    (let ((text (buffer-string)))
      (should-error (evil-delete (point-min) (1+ (point-min)) 'exclusive)
                    :type 'user-error)
      (should-error (evil-delete (line-beginning-position) (point-max) 'line)
                    :type 'user-error)
      (should (equal (buffer-string) text)))))

(ert-deftest my-eat-evil-regressions-live-shell ()
  "Consecutive edits, wide characters, prompts and registers work in Bash."
  (skip-unless (executable-find "bash"))
  (dolist (case '(("abcdef" "RESULT:a" "x x" "adef")
                  ("abcdef" "RESULT:a" "i Z <backspace> Y <escape>" "aYbcdef")
                  ("abcdef" "RESULT:a" "i <left> Z <escape>" "Zabcdef")
                  ("abcdef" "RESULT:a" "i Z <escape> x" "abcdef")
                  ("abcdef" "RESULT:a" "i Z Z <escape> h 2 x" "abcdef")
                  ("abcdef" "RESULT:a" "x i Z <escape>" "aZcdef")
                  ("a中bcd" "RESULT:" "i Z <escape>" "Za中bcd")
                  ("a中bcd" "RESULT:a" "d l" "abcd")
                  ("a中bcd" "RESULT:" "d 4 l" "cd")))
    (let ((eat-buffer-name "*my-eat-regression-test*")
          (eat-shell "bash --noprofile --norc -i"))
      (unwind-protect
          (progn
            (my/eat-toggle)
            (let ((process (get-buffer-process (current-buffer))))
              (should (my-eat-test--wait-for-text (current-buffer) process my-eat-test--bash-prompt))
              (my-eat-test--enable-integration process)
              (eat-term-send-string eat-terminal
                                    (format "printf 'RESULT:%s\\n'" (nth 0 case)))
              (should (my-eat-test--wait-for-text
                       (current-buffer) process (concat "RESULT:" (nth 0 case))))
              (execute-kbd-macro (kbd "<escape>"))
              (goto-char my-eat--input-start)
              (search-forward (nth 1 case))
              (condition-case err
                  (execute-kbd-macro (kbd (nth 2 case)))
                (error (ert-fail (list case err my-eat--input-start
                                      (buffer-substring (line-beginning-position)
                                                        (line-end-position))))))
              (eat-term-send-string eat-terminal "\r")
              (should (my-eat-test--wait-for-text
                       (current-buffer) process (concat "\nRESULT:" (nth 3 case) "\n")))))
        (my-eat-test--kill-terminal eat-buffer-name)))))

(ert-deftest my-eat-evil-prompt-and-register-regressions ()
  "Prompt edits fail without input or register changes; deletes preserve 0."
  (skip-unless (executable-find "bash"))
  (let ((eat-buffer-name "*my-eat-boundary-test*")
        (eat-shell "bash --noprofile --norc -i"))
    (unwind-protect
        (progn
          (my/eat-toggle)
          (let ((process (get-buffer-process (current-buffer))))
            (should (my-eat-test--wait-for-text (current-buffer) process my-eat-test--bash-prompt))
            (my-eat-test--enable-integration process)
            (eat-term-send-string eat-terminal "printf 'RESULT:abcdef\\n'")
            (should (my-eat-test--wait-for-text (current-buffer) process "RESULT:abcdef"))
            (execute-kbd-macro (kbd "<escape>"))
            (evil-set-register ?0 "saved-yank")
            (evil-set-register ?- "saved-small-delete")
            (let ((text (buffer-string)))
              (dolist (keys '("0 x" "d 0" "0 i"))
                (goto-char my-eat--input-start)
                (search-forward "RESULT:a")
                (let (events)
                  (cl-letf (((symbol-function 'eat-term-input-event)
                             (lambda (&rest args) (push args events))))
                    (should-error (execute-kbd-macro (kbd keys)) :type 'user-error))
                  (should-not events))
                (should (equal (buffer-string) text))
                (should (equal (evil-get-register ?0) "saved-yank"))
                (should (equal (evil-get-register ?-) "saved-small-delete"))
                (evil-normal-state)))
            (goto-char my-eat--input-start)
            (search-forward "RESULT:a")
            (execute-kbd-macro (kbd "x"))
            (should (equal (evil-get-register ?0) "saved-yank"))
            (should (equal (evil-get-register ?-) "b"))
            (eat-term-send-string eat-terminal "\r")
            (should (my-eat-test--wait-for-text
                     (current-buffer) process "\nRESULT:acdef\n"))))
      (my-eat-test--kill-terminal eat-buffer-name))))

(ert-deftest my-eat-evil-continuation-prompt-regression ()
  "Continuation prompt edits fail before changing registers or sending input."
  (skip-unless (executable-find "bash"))
  (let ((eat-buffer-name "*my-eat-continuation-test*")
        (eat-shell "bash --noprofile --norc -i"))
    (unwind-protect
        (progn
          (my/eat-toggle)
          (let ((process (get-buffer-process (current-buffer))))
            (should (my-eat-test--wait-for-text (current-buffer) process my-eat-test--bash-prompt))
            (my-eat-test--enable-integration process)
            (eat-term-send-string eat-terminal "printf 'RESULT:abc\r")
            (should (my-eat-test--wait-for-text (current-buffer) process "\n> "))
            (eat-term-send-string eat-terminal "def'")
            (should (my-eat-test--wait-for-text (current-buffer) process "> def'"))
            (execute-kbd-macro (kbd "<escape>"))
            (evil-set-register ?0 "saved-yank")
            (evil-set-register ?- "saved-small-delete")
            (let ((text (buffer-string)))
              (dolist (keys '("0 x" "d 0" "0 i"))
                (goto-char (eat-term-display-cursor eat-terminal))
                (let (events)
                  (cl-letf (((symbol-function 'eat-term-input-event)
                             (lambda (&rest args) (push args events))))
                    (should-error (execute-kbd-macro (kbd keys)) :type 'user-error))
                  (should-not events))
                (should (equal (buffer-string) text))
                (should (equal (evil-get-register ?0) "saved-yank"))
                (should (equal (evil-get-register ?-) "saved-small-delete"))
                (evil-normal-state)))
            (eat-term-send-string eat-terminal "\r")
            (should (my-eat-test--wait-for-text
                     (current-buffer) process "\nRESULT:abc\ndef"))))
      (my-eat-test--kill-terminal eat-buffer-name))))

(ert-deftest my-eat-typing-wraps-without-invalidating-input ()
  "Ordinary typing can cross the terminal edge and execute a long command."
  (skip-unless (executable-find "bash"))
  (let ((eat-buffer-name "*my-eat-wrap-test*")
        (eat-shell "bash --noprofile --norc -i")
        (payload (make-string 100 ?x)))
    (unwind-protect
        (progn
          (my/eat-toggle)
          (let ((process (get-buffer-process (current-buffer))))
            (should (my-eat-test--wait-for-text (current-buffer) process my-eat-test--bash-prompt))
            (my-eat-test--enable-integration process)
            (eat-term-send-string eat-terminal "printf 'RESULT:")
            (should (my-eat-test--wait-for-text (current-buffer) process "RESULT:"))
            (let ((first-line (line-number-at-pos
                               (eat-term-display-cursor eat-terminal))))
              (execute-kbd-macro (concat payload "'"))
              (should (> (line-number-at-pos
                          (eat-term-display-cursor eat-terminal)) first-line)))
            (should (marker-position my-eat--input-start))
            (execute-kbd-macro (kbd "<return>"))
            (should (my-eat-test--wait-for-text
                     (current-buffer) process (concat "\nRESULT:" payload)))))
      (my-eat-test--kill-terminal eat-buffer-name))))

(ert-deftest my-eat-shell-completion-and-kill-remain-editable ()
  "Completion and kill input synchronize without predicting shell contents."
  (skip-unless (and (executable-find "bash") (executable-find "printenv")))
  (dolist (event '(completion kill))
    (let ((eat-buffer-name "*my-eat-unpredicted-test*")
          (eat-shell "bash --noprofile --norc -i"))
      (unwind-protect
          (progn
            (my/eat-toggle)
            (let ((process (get-buffer-process (current-buffer))))
              (should (my-eat-test--wait-for-text
                       (current-buffer) process my-eat-test--bash-prompt))
              (my-eat-test--enable-integration process)
              (eat-term-send-string eat-terminal "printen")
              (should (my-eat-test--wait-for-text (current-buffer) process "printen"))
              (if (eq event 'completion)
                  (execute-kbd-macro (kbd "<tab> H <escape>"))
                (eat-self-input 1 21)
                (execute-kbd-macro (kbd "H <escape>")))
              (should (marker-position my-eat--input-start))
              (should (equal (my-eat--text my-eat--input-start
                                          (eat-term-end eat-terminal))
                             (if (eq event 'completion) "printenv H" "H")))
              ;; Normal-state point is on H; deleting it must still work.
              (execute-kbd-macro (kbd "x"))
              (should (marker-position my-eat--input-start))
              (should (equal (my-eat--text my-eat--input-start
                                          (eat-term-end eat-terminal))
                             (if (eq event 'completion) "printenv " "")))))
        (my-eat-test--kill-terminal eat-buffer-name)))))

(ert-deftest my-eat-deletion-reflows-a-wrapped-command ()
  "Deleting within a non-final row preserves the prompt and further editing."
  (skip-unless (executable-find "bash"))
  (let ((eat-buffer-name "*my-eat-reflow-test*")
        (eat-shell "bash --noprofile --norc -i")
        (payload (make-string 100 ?x)))
    (unwind-protect
        (progn
          (my/eat-toggle)
          (let ((process (get-buffer-process (current-buffer))))
            (should (my-eat-test--wait-for-text
                     (current-buffer) process my-eat-test--bash-prompt))
            (my-eat-test--enable-integration process)
            (eat-term-send-string eat-terminal
                                  (concat "printf 'RESULT:abcdef" payload "\\n'"))
            (should (my-eat-test--wait-for-text
                     (current-buffer) process (concat "RESULT:abcdef" payload)))
            (eat-self-input 70 'left)
            (should (< (line-number-at-pos
                        (eat-term-display-cursor eat-terminal))
                       (line-number-at-pos (eat-term-end eat-terminal))))
            (execute-kbd-macro (kbd "<escape> x"))
            (should (marker-position my-eat--input-start))
            (should (equal (string-trim-right
                            (my-eat--text my-eat--input-start
                                          (eat-term-end eat-terminal)))
                           (concat "printf 'RESULT:abcdef" (make-string 99 ?x) "\\n'")))
            (execute-kbd-macro (kbd "x"))
            (should (marker-position my-eat--input-start))
            (eat-term-send-string eat-terminal "\r")
            (should (my-eat-test--wait-for-text
                     (current-buffer) process
                     (concat "\nRESULT:abcdef" (make-string 98 ?x) "\n")))))
      (my-eat-test--kill-terminal eat-buffer-name))))

;;; my-eat-test.el ends here
