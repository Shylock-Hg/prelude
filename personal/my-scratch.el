;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'scratch)

(use-package scratch
  :ensure t)

(defun scratch-text ()
  (interactive)
  (scratch 'text-mode)
  )

(provide 'my-scratch)
