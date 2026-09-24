;;; -*- lexical-binding: t; -*-

;; Focused tests for the Eat terminal configuration in personal/my-eat.el.

(require 'ert)
(require 'seq)
(require 'evil)
(require 'eat)
(require 'my-eat)

;; Keep the real Evil state machine and its pre/post command hooks active.
(evil-mode 1)

(defconst my-eat-test--timeout 5.0
  "Seconds to wait for a terminal process to produce output.")

(defun my-eat-test--wait-for-text (buffer process text)
  "Wait up to `my-eat-test--timeout' for TEXT in BUFFER."
  (let ((deadline (+ (float-time) my-eat-test--timeout))
        found)
    (while (and (not found) (< (float-time) deadline))
      (with-current-buffer buffer
        (save-excursion
          (goto-char (point-min))
          (setq found (search-forward text nil t))))
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
  (dolist (command '(my-eat-toggle my-eat-new my-eat-next my-eat-prev))
    (should (commandp command))))

(ert-deftest my-eat-reserves-the-toggle-key ()
  "The toggle key is not swallowed by Eat and is bound to the toggle."
  (should (member (vconcat (kbd my-eat-toggle-key))
                  eat-semi-char-non-bound-keys))
  (should (eq (lookup-key eat-mode-map (kbd my-eat-toggle-key))
              #'my-eat-toggle)))

(ert-deftest my-eat-binds-evil-keys ()
  "The toggle and session keys are bound in Evil's normal/insert states."
  (should (eq (lookup-key evil-normal-state-map (kbd my-eat-toggle-key))
              #'my-eat-toggle))
  (with-temp-buffer
    (eat-mode)
    (let ((normal (evil-get-auxiliary-keymap eat-mode-map 'normal t t))
          (insert (evil-get-auxiliary-keymap eat-mode-map 'insert t t)))
      (should (eq (lookup-key normal (kbd ",c")) #'my-eat-new))
      (should (eq (lookup-key normal (kbd ",n")) #'my-eat-next))
      (should (eq (lookup-key normal (kbd ",p")) #'my-eat-prev))
      (should (eq (lookup-key insert (kbd my-eat-toggle-key))
                  #'my-eat-toggle)))))

(ert-deftest my-eat-toggle-starts-and-hides-a-terminal ()
  "`my-eat-toggle' shows a live terminal, then hides its window."
  (let ((eat-buffer-name "*my-eat-toggle-test*"))
    (unwind-protect
        (progn
          (my-eat-toggle)
          (should (derived-mode-p 'eat-mode))
          (should (get-buffer-window eat-buffer-name))
          (should (process-live-p (get-buffer-process eat-buffer-name)))
          (my-eat-toggle)
          (should-not (get-buffer-window eat-buffer-name))
          (should (buffer-live-p (get-buffer eat-buffer-name))))
      (my-eat-test--kill-terminal eat-buffer-name))))

(ert-deftest my-eat-new-creates-an-independent-session ()
  "`my-eat-new' starts a second terminal next to the default one."
  (let ((eat-buffer-name "*my-eat-new-test*"))
    (unwind-protect
        (progn
          (my-eat-toggle)
          (let ((first (get-buffer eat-buffer-name))
                (count (length (my-eat--buffers))))
            (my-eat-new)
            (should (derived-mode-p 'eat-mode))
            (should-not (eq (current-buffer) first))
            (should (= (length (my-eat--buffers)) (1+ count)))
            (should (process-live-p (get-buffer-process (current-buffer))))))
      (dolist (buffer (my-eat--buffers))
        (when (string-prefix-p eat-buffer-name (buffer-name buffer))
          (my-eat-test--kill-terminal (buffer-name buffer)))))))

(ert-deftest my-eat-next-and-prev-cycle-sessions ()
  "`my-eat-next' and `my-eat-prev' cycle through the live sessions."
  (let ((eat-buffer-name "*my-eat-cycle-test*"))
    (unwind-protect
        (progn
          (my-eat-toggle)
          (my-eat-new)
          (let* ((buffers (my-eat--buffers))
                 (first (car buffers))
                 (last (car (last buffers))))
            (pop-to-buffer first)
            (my-eat-next)
            (should-not (eq (current-buffer) first))
            (my-eat-prev)
            (should (eq (current-buffer) first))
            (my-eat-prev)
            (should (eq (current-buffer) last))))
      (dolist (buffer (my-eat--buffers))
        (when (string-prefix-p eat-buffer-name (buffer-name buffer))
          (my-eat-test--kill-terminal (buffer-name buffer)))))))

(ert-deftest my-eat-cycle-errors-without-a-terminal ()
  "Cycling without a running terminal signals a user error."
  (should-error (my-eat-next) :type 'user-error)
  (should-error (my-eat-prev) :type 'user-error))

(ert-deftest my-eat-runs-a-shell-command ()
  "A terminal started through the configuration really runs a shell."
  (let ((eat-buffer-name "*my-eat-shell-test*"))
    (unwind-protect
        (progn
          (my-eat-toggle)
          (let ((buffer (get-buffer eat-buffer-name)))
            (with-current-buffer buffer
              (goto-char (point-max))
              (eat-term-send-string eat-terminal "printf 'MYEAT_HELLO\n'")
              (eat-term-send-string eat-terminal "\r"))
            (should (my-eat-test--wait-for-text
                     buffer (get-buffer-process buffer) "MYEAT_HELLO"))))
      (my-eat-test--kill-terminal eat-buffer-name))))

;;; my-eat-test.el ends here
