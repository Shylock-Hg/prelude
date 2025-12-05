;;; early-init.el --- Early Init File -*- no-byte-compile: t; lexical-binding: t; -*-

;; avoid conflict with straight.el
(setq package-enable-at-startup nil)

;;;; Ensure Emacs loads the most recent byte-compiled files.
;;(setq load-prefer-newer t)
;;;;; Make Emacs Native-compile .elc files asynchronously by setting
;;;; `native-comp-jit-compilation' to t.
;;(setq native-comp-jit-compilation t)
;;(setq native-comp-deferred-compilation native-comp-jit-compilation)  ; Deprecated
