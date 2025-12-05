;;; -*- lexical-binding: t -*-

;; set mirrors
;;(setq package-archives '(("gnu"    . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
                         ;;("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
                         ;;("melpa"  . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))
;; ustc
;;(setq package-archives '(("gnu" . "https://mirrors.ustc.edu.cn/elpa/gnu/")
                         ;;("melpa" . "https://mirrors.ustc.edu.cn/elpa/melpa/")
                         ;;("nongnu" . "https://mirrors.ustc.edu.cn/elpa/nongnu/")))
(setq package-archives '(("gnu"    . "https://mirrors.zju.edu.cn/elpa/gnu/")
                         ("nongnu" . "https://mirrors.zju.edu.cn/elpa/nongnu/")
                         ("melpa"  . "https://mirrors.zju.edu.cn/elpa/melpa/")))

(package-initialize) ;; You might already have this line


;; load compile-angel
(use-package compile-angel
  :ensure t
  :demand t
  :config
  ;; Set `compile-angel-verbose' to nil to disable compile-angel messages.
  ;; (When set to nil, compile-angel won't show which file is being compiled.)
  (setq compile-angel-verbose t)

  ;; Uncomment the line below to compile automatically when an Elisp file is saved
  ;; (add-hook 'emacs-lisp-mode-hook #'compile-angel-on-save-local-mode)

  ;; The following directive prevents compile-angel from compiling your init
  ;; files. If you choose to remove this push to `compile-angel-excluded-files'
  ;; and compile your pre/post-init files, ensure you understand the
  ;; implications and thoroughly test your code. For example, if you're using
  ;; the `use-package' macro, you'll need to explicitly add:
  ;; (eval-when-compile (require 'use-package))
  ;; at the top of your init file.
  (push "/init.el" compile-angel-excluded-files)
  (push "/early-init.el" compile-angel-excluded-files)

  ;; A global mode that compiles .el files before they are loaded
  ;; using `load' or `require'.
  (compile-angel-on-load-mode 1))

;; preset for evil
(setq evil-want-keybinding nil)
