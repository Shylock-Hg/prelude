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

(gptel-make-openai "Zhipu GLM"
    :host "open.bigmodel.cn"                  ; Zhipu API host
    :endpoint "/api/paas/v4/chat/completions" ; Chat endpoint
    :stream t                                 ; Enable streaming responses
    :key #'gptel-api-key-from-auth-source     ; Secure key retrieval (from .authinfo)
    ;; :key (getenv "ZHIPU_API_KEY")
    :models '("glm-4-flash"))

(gptel-make-openai "Minimax"
    :host "api.minimax.chat"                  ; host
    :endpoint "/v1/chat/completions"
    :stream t                                 ; Enable streaming responses
    :key #'gptel-api-key-from-auth-source     ; Secure key retrieval (from .authinfo)
    ;; :key (getenv "ZHIPU_API_KEY")
    :models '("abab6.5s-chat"      ; MiniMax 模型
                  "abab6.5-chat"
                  "abab6-chat")
    )

(gptel-make-openai "Kimi"
    :host "api.kimi.com"                  ; host
    :endpoint "/coding/v1"
    :stream t                                 ; Enable streaming responses
    :key #'gptel-api-key-from-auth-source     ; Secure key retrieval (from .authinfo)
    ;; :key (getenv "ZHIPU_API_KEY")
    :models '("kimi-for-coding")
    :header '(
        ("User-Agent" . "KimiCLI/1.12.0")
        ("X-Msh-Platform" . "kimi_cli")
        ("X-Msh-Version" . "1.12.0"))
    )

(gptel-make-openai "Moonshot"
  :host "api.moonshot.cn" ;; or "api.moonshot.ai" for the global site
  :key #'gptel-api-key-from-auth-source     ; Secure key retrieval (from .authinfo)
  :stream t ;; optionally enable streaming
  :models '(kimi-latest kimi-k3 kimi-k2.7-code))

(setq my-aliyuncs-backend (gptel-make-openai "Aliyuncs"
    :host "dashscope.aliyuncs.com"                  ; host
    :endpoint "/compatible-mode/v1/chat/completions"
    :stream t                                 ; Enable streaming responses
    :key #'gptel-api-key-from-auth-source     ; Secure key retrieval (from .authinfo)
    :models '("qwen3.8-max" "qwen3.5-plus" "qwen3-coder-plus" "kimi-k2.5" "kimi/kimi-k3" "deepseek-v4-pro" "glm-5.2")
    ))


;;(setq gptel-model 'grok-3-latest
      ;;gptel-backend
      ;;(gptel-make-xai "xAI"               ; Any name you want
        ;;:key 'gptel-api-key-from-auth-source
        ;;:stream t))
(gptel-make-xai "xAI"               ; Any name you want
        :key 'gptel-api-key-from-auth-source
        :stream t)

;; OpenRouter offers an OpenAI compatible API
(gptel-make-openai "OpenRouter"               ;Any name you want
  :host "openrouter.ai"
  :endpoint "/api/v1/chat/completions"
  :stream t
  :key 'gptel-api-key-from-auth-source
  :models '(openai/gpt-3.5-turbo
            mistralai/mixtral-8x7b-instruct
            meta-llama/codellama-34b-instruct
            meta-llama/llama-3.2-3b-instruct
            codellama/codellama-70b-instruct
            google/palm-2-codechat-bison-32k
            google/gemini-pro))


(setq
  gptel-model 'qwen3.5-plus
  gptel-backend my-aliyuncs-backend
  )

(provide 'my-gptel)
