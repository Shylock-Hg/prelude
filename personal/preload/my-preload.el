;;; -*- lexical-binding: t -*-

;; set mirrors
;;(setq package-archives '(("gnu"    . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
                         ;;("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
                         ;;("melpa"  . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))
;; ustc
(setq package-archives '(("gnu" . "https://mirrors.ustc.edu.cn/elpa/gnu/")
                         ("melpa" . "https://mirrors.ustc.edu.cn/elpa/melpa/")
                         ("nongnu" . "https://mirrors.ustc.edu.cn/elpa/nongnu/")))
;;(setq package-archives
    ;;'(("melpa-cn" . "http://1.15.88.122/melpa/")
      ;;("org-cn"   . "http://1.15.88.122/org/")
      ;;("nognu-cn"   . "http://1.15.88.122/nognu/")
      ;;("gnu-cn"   . "http://1.15.88.122/gnu/")))
;;(package-initialize) ;; You might already have this line

;; bootstrap straight.el
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        (or (bound-and-true-p straight-base-dir)
            user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(straight-use-package 'use-package)
(setq straight-use-package-by-default t)

(require 'straight)

;; load compile-angel
;;(use-package compile-angel
  ;;:straight t
  ;;:demand t
  ;;:config
  ;;;; Set `compile-angel-verbose' to nil to disable compile-angel messages.
  ;;;; (When set to nil, compile-angel won't show which file is being compiled.)
  ;;(setq compile-angel-verbose t)
;;
  ;;;; Uncomment the line below to compile automatically when an Elisp file is saved
  ;;;; (add-hook 'emacs-lisp-mode-hook #'compile-angel-on-save-local-mode)
;;
  ;;;; The following directive prevents compile-angel from compiling your init
  ;;;; files. If you choose to remove this push to `compile-angel-excluded-files'
  ;;;; and compile your pre/post-init files, ensure you understand the
  ;;;; implications and thoroughly test your code. For example, if you're using
  ;;;; the `use-package' macro, you'll need to explicitly add:
  ;;;; (eval-when-compile (require 'use-package))
  ;;;; at the top of your init file.
  ;;(push "/init.el" compile-angel-excluded-files)
  ;;(push "/early-init.el" compile-angel-excluded-files)
;;
  ;;;; A global mode that compiles .el files before they are loaded
  ;;;; using `load' or `require'.
  ;;(compile-angel-on-load-mode 1))

;; preset for evil
(setq evil-want-keybinding nil)

(straight-use-package
 '(discover-my-major :type git :host github :repo "jguenther/discover-my-major"))
