;;; my-translate.el --- Translate selected text with gt -*- lexical-binding: t -*-

;;; Commentary:

;; Translate the active region or last Evil visual selection with Google
;; Translate, displaying the result in a separate gt buffer.

;;; Code:

(require 'prelude-packages)
(require 'my-utils)

(prelude-require-package 'gt)
(require 'gt)

(defun my-translate--selected (source target)
  "Translate selected text from SOURCE to TARGET in a gt buffer."
  (let ((text (my--selected-text)))
    (unless (and text (not (string-blank-p text)))
      (user-error "Select text to translate first"))
    (gt-start
     (gt-translator
      :taker (gt-taker :text (lambda () text)
                       ;; A nil first element bypasses language detection.
                       :langs (list nil (list source target))
                       :prompt nil :pick nil)
      :engines (gt-google-engine)
      :render (gt-buffer-render)))))

(defun my/translate-en2zh-selected ()
  "Translate selected English text to Chinese in a separate buffer.
Use the active region or last Evil visual selection, including when
invoked through the extended-command minibuffer."
  (interactive)
  (my-translate--selected 'en 'zh))

(defun my/translate-zh2en-selected ()
  "Translate selected Chinese text to English in a separate buffer.
Use the active region or last Evil visual selection, including when
invoked through the extended-command minibuffer."
  (interactive)
  (my-translate--selected 'zh 'en))

(provide 'my-translate)
;;; my-translate.el ends here
