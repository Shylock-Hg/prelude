;;; -*- lexical-binding: t -*-

(require 'subr-x)

(defun my-open-file-selected ()
  "Open the selected file path and jump to its optional line number."
  (interactive)
  (let* ((selection
          (or (when (and (fboundp 'evil-visual-state-p)
                         (evil-visual-state-p)
                         (region-active-p))
                (buffer-substring-no-properties
                 (region-beginning) (region-end)))
              (when (use-region-p)
                (buffer-substring-no-properties
                 (region-beginning) (region-end)))))
         (selected-text (and selection (string-trim selection)))
         file line)
    (unless selection
      (user-error "No active region or Evil visual selection"))
    (when (string-empty-p selected-text)
      (user-error "The selected text is empty"))
    (when (string-match "\\`\\(.+\\):\\([0-9]+\\)\\'" selected-text)
      (let ((line-number (string-to-number (match-string 2 selected-text))))
        (when (> line-number 0)
          (setq file (match-string 1 selected-text)
                line line-number))))
    (unless file
      (setq file selected-text))
    (unless (file-regular-p file)
      (user-error "Selected path is not a file: %s" file))
    (let ((buffer (find-file file)))
      (when line
        (with-current-buffer buffer
          (goto-char (point-min))
          (forward-line (1- line))))
      buffer)))

(provide 'my-utils)
