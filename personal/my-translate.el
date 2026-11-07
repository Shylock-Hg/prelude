;;; my-translate.el --- Translate selected text with gt -*- lexical-binding: t -*-

;;; Commentary:

;; Translate the active region or last Evil visual selection with Google
;; Translate, displaying the result in a childframe via posframe.

;;; Code:

(require 'prelude-packages)
(require 'my-utils)
(require 'cl-lib)
(require 'color)

(prelude-require-package 'gt)
(prelude-require-package 'posframe)
(require 'gt)

;; Prefer the active theme over gt's default black popup.  These nil values
;; also let posframe inherit the frame colors when no concrete color is set.
(setq gt-pop-posframe-forecolor nil
      gt-pop-posframe-backcolor nil)

(defconst my-translate--popup-background-tint 0.1
  "Fraction of the theme foreground mixed into the popup background.")

(defun my-translate--theme-color (attribute)
  "Return ATTRIBUTE of the default face for the current frame.
Return nil when the face value is not a concrete color."
  (let ((value (face-attribute 'default attribute (selected-frame) t)))
    (unless (or (not (stringp value))
                (string-prefix-p "unspecified" value))
      value)))

(defun my-translate--mix-color (base tint amount)
  "Return BASE mixed with TINT by AMOUNT as a 24-bit hex color.
Return nil when either color is not a concrete color."
  (let ((base-rgb (and base (color-name-to-rgb base)))
        (tint-rgb (and tint (color-name-to-rgb tint))))
    (when (and base-rgb tint-rgb)
      (let ((mixed (cl-mapcar (lambda (base-channel tint-channel)
                                (+ (* base-channel (- 1 amount))
                                   (* tint-channel amount)))
                              base-rgb tint-rgb)))
        (apply #'color-rgb-to-hex (append mixed '(2)))))))

(defun my-translate--popup-background (foreground background)
  "Tint BACKGROUND slightly toward FOREGROUND for the popup."
  (or (my-translate--mix-color background foreground
                               my-translate--popup-background-tint)
      background))

(defun my-translate--posframe-render ()
  "Return a gt popup renderer using the current theme's colors."
  (let* ((forecolor (my-translate--theme-color :foreground))
         (backcolor (my-translate--theme-color :background)))
    (gt-posframe-pop-render
     :forecolor forecolor
     :backcolor (my-translate--popup-background forecolor backcolor))))

(defun my-translate--selected (source target)
  "Translate selected text from SOURCE to TARGET in a posframe childframe."
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
      :render (my-translate--posframe-render)))))

(defun my/translate-en2zh-selected ()
  "Translate selected English text to Chinese in a posframe childframe.
Use the active region or last Evil visual selection, including when
invoked through the extended-command minibuffer."
  (interactive)
  (my-translate--selected 'en 'zh))

(defun my/translate-zh2en-selected ()
  "Translate selected Chinese text to English in a posframe childframe.
Use the active region or last Evil visual selection, including when
invoked through the extended-command minibuffer."
  (interactive)
  (my-translate--selected 'zh 'en))

(provide 'my-translate)
;;; my-translate.el ends here
