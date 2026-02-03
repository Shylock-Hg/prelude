;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'gptel)

(use-package gptel
  :ensure t
  :demand t
  )

(require 'gptel)

;; from auth source by default
;;(setq gptel-api-key #'gptel-api-key-from-auth-source)

;;(setq
  ;;gptel-model 'gemini-2.5-flash
  ;;gptel-backend (gptel-make-gemini "Gemini"
                  ;;:key 'gptel-api-key-from-auth-source
                  ;;:stream t))
(gptel-make-gemini "Gemini"
                  :key 'gptel-api-key-from-auth-source
                  :stream t)

(setq
  gptel-model 'glm-4-flash
  gptel-backend
  (gptel-make-openai "Zhipu GLM"
      :host "open.bigmodel.cn"                  ; Zhipu API host
      :endpoint "/api/paas/v4/chat/completions" ; Chat endpoint
      :stream t                                 ; Enable streaming responses
      :key #'gptel-api-key-from-auth-source     ; Secure key retrieval (from .authinfo)
      ;; :key (getenv "ZHIPU_API_KEY")
      :models '("glm-4-flash"))
  )

;;(setq gptel-model 'grok-3-latest
      ;;gptel-backend
      ;;(gptel-make-xai "xAI"               ; Any name you want
        ;;:key 'gptel-api-key-from-auth-source
        ;;:stream t))
(gptel-make-xai "xAI"               ; Any name you want
        :key 'gptel-api-key-from-auth-source
        :stream t)

(provide 'my-gptel)
