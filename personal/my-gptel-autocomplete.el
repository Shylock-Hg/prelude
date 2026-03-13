;;; -*- lexical-binding: t -*-

(require 'my-vendor)

(defvar my-gptel-autocomplete-fresh-installed (my-vendor-install-git "github.com" "JDNdeveloper" "gptel-autocomplete"))

(defvar my-gptel-autocomplete-dir (my-vendor-dest "JDNdeveloper" "gptel-autocomplete"))

(add-to-list 'load-path my-gptel-autocomplete-dir)

(require 'gptel-autocomplete)

(setq gptel-autocomplete-idle-delay 0.1)

(add-hook 'gptel-autocomplete-mode-hook
          (lambda ()
            (define-key evil-insert-state-local-map
                        (kbd "C-<return>") #'gptel-accept-completion)
            (gptel-autocomplete-mode t)
            )
          )


(provide 'my-gptel-autocomplete)
