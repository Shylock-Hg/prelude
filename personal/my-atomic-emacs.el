;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'atomic-chrome)

(use-package atomic-chrome
  :config
  (setq atomic-chrome-default-major-mode 'text-mode
        atomic-chrome-buffer-open-style 'full
        atomic-chrome-enable-auto-update nil)

  (atomic-chrome-start-server)
  )

(provide 'my-atomic-emacs)
