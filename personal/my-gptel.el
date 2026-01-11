;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'gptel)

(use-package gptel
  :ensure t
  :demand t
  )

(require 'gptel)

(setq gptel-api-key #'gptel-api-key-from-auth-source)
(setq
  gptel-model 'gemini-2.5-flash
  gptel-backend (gptel-make-gemini "Gemini"
                  :key 'gptel-api-key-from-auth-source
                  :stream t))
;;(setq gptel-model 'grok-3-latest
      ;;gptel-backend
      ;;(gptel-make-xai "xAI"               ; Any name you want
        ;;:key 'gptel-api-key-from-auth-source
        ;;:stream t))

(provide 'my-gptel)
