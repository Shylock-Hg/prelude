;;; -*- lexical-binding: t -*-

(require 'subr-x)

;; Defined by Evil when it is available; declared here to keep the byte
;; compiler quiet.
(defvar evil-visual-beginning)
(defvar evil-visual-end)

(defun my--selected-text ()
  "Return the text selected in the current buffer, or nil.
Prefer the active region (which covers an expanded Evil visual
selection).  When there is no active region, fall back to the last Evil
visual selection so that the command still works when it is invoked
through the `C-,' minibuffer and the region is no longer active."
  (let ((range
         (cond
          ((use-region-p)
           (cons (region-beginning) (region-end)))
          ((and (boundp 'evil-visual-beginning)
                (markerp evil-visual-beginning)
                (markerp evil-visual-end))
           (cons evil-visual-beginning evil-visual-end)))))
    (when (and range
               (< (car range) (cdr range)))
      (buffer-substring-no-properties (car range) (cdr range)))))

(defun my-open-file-selected ()
  "Open the selected file path and jump to its optional line number.
The path comes from the active region, an Evil visual selection, or the
most recent Evil visual selection when the command is invoked via
`execute-extended-command'."
  (interactive)
  (let* ((selection (my--selected-text))
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

;; The command is occasionally invoked as `my/open-file-selected'; keep
;; that spelling working as an alias.
(defalias 'my/open-file-selected #'my-open-file-selected)

(provide 'my-utils)
