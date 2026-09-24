;;; -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'evil)
(require 'flyspell)
(require 'my-config)
(require 'my-vterm)
(require 'vterm)

;; Keep the real Evil state machine and its pre/post command hooks active.
(evil-mode 1)

(defconst my-vterm-test--repo-root
  (expand-file-name ".."
                    (file-name-directory
                     (or load-file-name buffer-file-name)))
  "Repository root for the focused vterm tests.")

(defconst my-vterm-test--timeout 5.0)

(defun my-vterm-test--wait-for-text (buffer process text)
  "Wait up to `my-vterm-test--timeout' for TEXT in BUFFER."
  (let ((deadline (+ (float-time) my-vterm-test--timeout))
        found)
    (while (and (not found) (< (float-time) deadline))
      (with-current-buffer buffer
        (save-excursion
          (goto-char (point-min))
          (setq found (search-forward text nil t))))
      (unless found
        (accept-process-output process 0.05)))
    found))

(defun my-vterm-test--printf (text)
  "Return a shell printf command that emits TEXT without echoing it."
  (format "printf '%%b' '%s'"
          (mapconcat (lambda (char) (format "\\%03o" char))
                     (string-to-list text) "")))

(defun my-vterm-test--cursor-state (buffer)
  "Return BUFFER's point, window point, region, and Evil state."
  (with-current-buffer buffer
    (list :point (point)
          :window-point (let ((window (get-buffer-window buffer t)))
                          (and window (window-point window)))
          :mark (mark t)
          :region (and (region-active-p)
                       (cons (region-beginning) (region-end)))
          :evil-state evil-state
          :selection evil-visual-selection
          :direction (and (evil-visual-state-p) (evil-visual-direction))
          :visual (evil-visual-state-p))))

(defun my-vterm-test--select (buffer text type direction)
  "Select TEXT in BUFFER with Evil selection TYPE and DIRECTION."
  (with-current-buffer buffer
    (let* ((end (save-excursion
                  (goto-char (point-min))
                  (search-forward text nil t)))
           (beg (and end (- end (length text))))
           (range (and end (evil-contract beg end type)))
           (mark (and range (evil-range-beginning range)))
           (point-pos (and range (evil-range-end range))))
      (unless end
        (error "Could not find %S in vterm buffer" text))
      (when (< direction 0)
        (cl-rotatef mark point-pos))
      (goto-char point-pos)
      (evil-visual-state)
      (should evil-local-mode)
      (should (memq #'evil-visual-pre-command pre-command-hook))
      (should (memq #'evil-visual-post-command post-command-hook))
      (setq evil-visual-selection (evil-visual-selection-for-type type))
      (evil-visual-make-region mark point-pos type)
      (my-vterm-test--cursor-state buffer))))

(defun my-vterm-test--cancel-extended-command-after-output
    (buffer process text)
  "Invoke the configured extended-command command and cancel after TEXT."
  (let* (prompt-state redraw-state saw-output prompt-buffer
        (cancel-hook
         (lambda ()
           (setq prompt-buffer (current-buffer))
           (setq prompt-state (my-vterm-test--cursor-state buffer))
           (setq prompt-state
                 (plist-put prompt-state :guard
                            (eq my-vterm--extended-command-source-buffer
                                buffer)))
           (setq saw-output (my-vterm-test--wait-for-text buffer process text))
           (setq redraw-state (my-vterm-test--cursor-state buffer))
           (keyboard-quit))))
    (add-hook 'minibuffer-setup-hook cancel-hook t)
    (unwind-protect
        (condition-case nil
            (execute-kbd-macro (kbd my-extended-command-key))
          (quit nil))
      (remove-hook 'minibuffer-setup-hook cancel-hook))
    (list prompt-state redraw-state saw-output
          (my-vterm-test--cursor-state buffer)
          (and (buffer-live-p prompt-buffer)
               (null (buffer-local-value
                      'my-vterm--extended-command-source-buffer
                      prompt-buffer))))))

(defun my-vterm-test--live-output-script ()
  "Return a shell command that emits delayed output during a prompt."
  (let* ((script
          (mapconcat
           #'identity
           (list (my-vterm-test--printf "READY1\nSECOND1\nTHIRD1\n")
                 "sleep 0.8"
                 (my-vterm-test--printf "BACKGROUND1\n")
                 "IFS= read -r input"
                 (my-vterm-test--printf "FINISHED\n"))
           "; "))
         (encoded (base64-encode-string script t)))
    (format "printf '%%s' '%s' | base64 -d | sh" encoded)))

(ert-deftest my-vterm-extended-command-preserves-visual-selection-during-redraw ()
  "C-, preserves a visual selection if vterm redraws while its prompt is open."
  (let ((previous-buffer (current-buffer)))
    (unwind-protect
        (progn
          (require 'flyspell)
          (should-not (lookup-key flyspell-mode-map
                                  (kbd my-extended-command-key)))
          (dolist (case '((inclusive 1 char)
                          (inclusive -1 char)
                          (line 1 line)))
            (pcase-let ((`(,type ,direction ,selection) case))
              (let* ((buffer (generate-new-buffer " *my-vterm-issue-9-test*"))
                     process)
                (unwind-protect
                    (progn
                      (switch-to-buffer buffer)
                      (vterm-mode)
                      (setq process vterm--process)
                      (vterm-send-string (my-vterm-test--live-output-script))
                      (vterm-send-return)
                      (should (my-vterm-test--wait-for-text
                               buffer process "SECOND1"))
                      (evil-normal-state)
                      (should (eq (key-binding (kbd my-extended-command-key) t)
                                  #'execute-extended-command))
                      (evil-insert-state)
                      (should (eq (key-binding (kbd my-extended-command-key) t)
                                  #'execute-extended-command))
                      (evil-normal-state)
                      (let ((selected
                             (my-vterm-test--select
                              buffer "SECOND1" type direction)))
                        (should (eq (plist-get selected :selection) selection))
                        (should (= (plist-get selected :direction) direction)))
                      (should (eq (key-binding (kbd my-extended-command-key) t)
                                  #'execute-extended-command))
                      (let* ((states
                              (my-vterm-test--cancel-extended-command-after-output
                               buffer process "BACKGROUND1"))
                             (prompt (nth 0 states))
                             (redraw (nth 1 states))
                             (saw-output (nth 2 states))
                             (after-cancel (nth 3 states))
                             (guard-cleared (nth 4 states)))
                        (should saw-output)
                        (should guard-cleared)
                        (should (plist-get prompt :guard))
                        (should (eq (plist-get prompt :evil-state) 'visual))
                        (should (plist-get prompt :visual))
                        (should (eq (plist-get redraw :evil-state) 'visual))
                        (should (plist-get redraw :visual))
                        (should (= (plist-get prompt :point)
                                   (plist-get redraw :point)))
                        (should (= (plist-get prompt :window-point)
                                   (plist-get redraw :window-point)))
                        (should (= (plist-get prompt :mark)
                                   (plist-get redraw :mark)))
                        (should (equal (plist-get prompt :region)
                                       (plist-get redraw :region)))
                        (should (= (plist-get redraw :point)
                                   (plist-get after-cancel :point)))
                        (should (= (plist-get redraw :window-point)
                                   (plist-get after-cancel :window-point)))
                        (should (equal (plist-get redraw :region)
                                       (plist-get after-cancel :region))))
                      (evil-normal-state)
                      (vterm-send-string "GO")
                      (vterm-send-return)
                      (should (my-vterm-test--wait-for-text
                               buffer process "FINISHED"))
                      (vterm-send-string (my-vterm-test--printf "INPUT_OK\n"))
                      (vterm-send-return)
                      (should (my-vterm-test--wait-for-text
                               buffer process "INPUT_OK"))
                      (should (> (point) (point-min)))
                      (should (eq evil-state 'normal)))
                  (when (and (processp process) (process-live-p process))
                    (set-process-query-on-exit-flag process nil)
                    (delete-process process))
                  (when (buffer-live-p buffer)
                    (kill-buffer buffer)))))))
      (when (buffer-live-p previous-buffer)
        (switch-to-buffer previous-buffer)))))

(ert-deftest my-vterm-extended-command-preserves-ordinary-cursor-during-redraw ()
  "C-, preserves a nonvisual vterm cursor while output redraws the buffer."
  (let ((previous-buffer (current-buffer)))
    (unwind-protect
        (dolist (state '(normal insert))
          (let ((buffer (generate-new-buffer " *my-vterm-cursor-test*"))
                process)
            (unwind-protect
                (progn
                  (switch-to-buffer buffer)
                  (vterm-mode)
                  (setq process vterm--process)
                  (vterm-send-string (my-vterm-test--live-output-script))
                  (vterm-send-return)
                  (should (my-vterm-test--wait-for-text
                           buffer process "SECOND1"))
                  (evil-normal-state)
                  (goto-char
                   (save-excursion
                     (goto-char (point-min))
                     (+ 3 (search-forward "SECOND1" nil t)
                        (- (length "SECOND1")))))
                  (when (eq state 'insert)
                    (evil-insert-state))
                  (should-not (region-active-p))
                  (should (< (point) (point-max)))
                  (should (/= (point) (vterm--get-cursor-point)))
                  (should (eq evil-state state))
                  (should (eq (key-binding (kbd my-extended-command-key) t)
                              #'execute-extended-command))
                  (let* ((states
                          (my-vterm-test--cancel-extended-command-after-output
                           buffer process "BACKGROUND1"))
                         (prompt (nth 0 states))
                         (redraw (nth 1 states))
                         (saw-output (nth 2 states))
                         (after-cancel (nth 3 states))
                         (guard-cleared (nth 4 states)))
                    (should saw-output)
                    (should-not (plist-get prompt :region))
                    (should (= (plist-get prompt :point)
                               (plist-get redraw :point)))
                    (should (= (plist-get prompt :window-point)
                               (plist-get redraw :window-point)))
                    (should (eq (plist-get prompt :evil-state) state))
                    (should guard-cleared)
                    (should (plist-get prompt :guard))
                    (should (= (plist-get redraw :point)
                               (plist-get after-cancel :point)))
                    (should (= (plist-get redraw :window-point)
                               (plist-get after-cancel :window-point))))
                  (evil-normal-state)
                  (vterm-send-string "GO")
                  (vterm-send-return)
                  (should (my-vterm-test--wait-for-text
                           buffer process "FINISHED"))
                  (vterm-send-string (my-vterm-test--printf "INPUT_OK\n"))
                  (vterm-send-return)
                  (should (my-vterm-test--wait-for-text
                           buffer process "INPUT_OK")))
              (when (and (processp process) (process-live-p process))
                (set-process-query-on-exit-flag process nil)
                (delete-process process))
              (when (buffer-live-p buffer)
                (kill-buffer buffer)))))
      (when (buffer-live-p previous-buffer)
        (switch-to-buffer previous-buffer)))))

(defun my-vterm-test--move-point-intentionally ()
  "Test command that deliberately advances point by two characters."
  (interactive)
  (forward-char 2))

(defun my-vterm-test--exit-minibuffer (buffer)
  "Exit BUFFER when it is the active minibuffer."
  (when (and (buffer-live-p buffer)
             (eq (active-minibuffer-window) (get-buffer-window buffer t))
             (> (minibuffer-depth) 0))
    (with-current-buffer buffer
      (when (minibufferp)
        (exit-minibuffer)))))

(ert-deftest my-vterm-extended-command-keeps-selected-command-movement ()
  "C-, accepts a command in vterm and retains its intentional point movement."
  (let ((buffer (generate-new-buffer " *my-vterm-command-test*"))
        (previous-buffer (current-buffer))
        process)
    (unwind-protect
        (progn
          (switch-to-buffer buffer)
          (vterm-mode)
          (setq process vterm--process)
          (vterm-send-string (my-vterm-test--printf "0123456789\n"))
          (vterm-send-return)
          (should (my-vterm-test--wait-for-text buffer process "456"))
          (accept-process-output process 0.1)
          (my-vterm-test--select buffer "456" 'inclusive 1)
          (let* ((expected (+ (point) 2))
                 guard-seen guard-minibuffer
                 (accept-command-hook
                  (lambda ()
                    (setq guard-minibuffer (current-buffer))
                    (setq guard-seen
                          (eq my-vterm--extended-command-source-buffer buffer))
                    (insert "my-vterm-test--move-point-intentionally")
                    (run-at-time 0 nil #'my-vterm-test--exit-minibuffer
                                 (current-buffer)))))
            (add-hook 'minibuffer-setup-hook accept-command-hook t)
            (unwind-protect
                (execute-kbd-macro (kbd my-extended-command-key))
              (remove-hook 'minibuffer-setup-hook accept-command-hook))
            (should guard-seen)
            (should (buffer-live-p guard-minibuffer))
            (should-not (buffer-local-value
                         'my-vterm--extended-command-source-buffer
                         guard-minibuffer))
            (should-not (active-minibuffer-window))
            (should (= (point) expected))))
      (when (and (processp process) (process-live-p process))
        (set-process-query-on-exit-flag process nil)
        (delete-process process))
      (when (buffer-live-p buffer)
        (kill-buffer buffer))
      (when (buffer-live-p previous-buffer)
        (switch-to-buffer previous-buffer)))))

(ert-deftest my-extended-command-key-honors-an-alternate-configuration ()
  "The keybinding and Flyspell exception use `my-extended-command-key'."
  (let ((global-map (copy-keymap global-map))
        (flyspell-mode-map (copy-keymap flyspell-mode-map))
        (my-extended-command-key "C-c ,")
        (server-start-function (symbol-function 'server-start)))
    (unwind-protect
        (progn
          (advice-add 'server-start :override #'ignore)
          (load (expand-file-name "personal/my-config.el"
                                  my-vterm-test--repo-root)
                nil t)
          (should (eq (lookup-key global-map (kbd my-extended-command-key))
                      #'execute-extended-command))
          (should-not (lookup-key flyspell-mode-map
                                  (kbd my-extended-command-key))))
      (advice-remove 'server-start #'ignore)
      (fset 'server-start server-start-function))))

(provide 'my-vterm-test)
;;; my-vterm-test.el ends here
