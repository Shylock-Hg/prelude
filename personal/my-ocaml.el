;;; -*- lexical-binding: t -*-
(require 'prelude-packages)

(prelude-require-packages '(ocaml-eglot tuareg))

(require 'my-eglot)

(use-package tuareg
  :ensure t
  )

(use-package ocaml-eglot
  :ensure t
  :after tuareg
)
(add-hook 'tuareg-mode-hook #'ocaml-eglot)
(add-hook 'ocaml-eglot-hook #'eglot-ensure)

(provide 'my-ocaml)
