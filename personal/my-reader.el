;;; -*- lexical-binding: t -*-

(require 'my-vendor)
(require 'use-package)

(defvar my-reader-fresh-installed (my-vendor-install-git "codeberg.org" "divyaranjan" "emacs-reader"))

(defvar my-reader-dir (my-vendor-dest "divyaranjan" "emacs-reader"))

(when (eq my-reader-fresh-installed t)
  (message "Compiling emacs-reader...")
  (let ((ec (call-process "make" nil nil nil "-j8" "-C" my-reader-dir "all" "autoloads")) )
    (when (not  (zerop ec))
      (error "Compile emacs reader failed.")
      )
    )
)

(add-to-list 'load-path my-reader-dir)

(require 'reader)
(require 'reader-autoloads)

(with-eval-after-load 'reader
  (add-hook 'reader-mode-hook (lambda ()
            (reader-fit-to-width)
            ) 10)
  )

(provide 'my-reader)
