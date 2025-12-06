;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'gptel)

(use-package gptel
  :ensure t
  :demand t
  )

(require 'gptel)

;;(gptel-make-gemini "Gemini" :key "AIzaSyDYg_G_Dp9OYafeJK9n3S2uLqrobPmBEps" :stream t)
;;(setq
  ;;gptel-model 'gemini-2.5-pro-exp-03-25
  ;;gptel-backend (gptel-make-gemini "Gemini"
                  ;;:key "YOUR KEY"
                  ;;:stream t))
;;(setq gptel-model 'grok-3-latest
      ;;gptel-backend
      ;;(gptel-make-xai "xAI"               ; Any name you want
        ;;:key "YOUR KEY"
        ;;:stream t))

(provide 'my-gptel)
