;;; -*- lexical-binding: t -*-

(require 'prelude-packages)
(prelude-require-packages '(magit forge))

(use-package magit :ensure t)
(with-eval-after-load 'magit
  (setq magit-diff-refine-hunk 'all)
  )
(use-package forge :ensure t :after magit
  :custom
  (forge-add-default-bindings t)
  :config
  ;;(add-to-list 'forge-alist '("work-wsl:9000" "work-wsl:9000/api/v4" "work-wsl:9000"
                              ;;forge-gitlab-repository))
  (add-to-list 'forge-alist '("work-wsl:7070" "work-wsl:9000/api/v4" "work-wsl:9000"
                              forge-gitlab-repository))
  (add-to-list 'forge-alist '("shylock-server" "shylock-server/gitlab/api/v4" "shylock-server/gitlab"
                              forge-gitlab-repository))
  (add-to-list 'ghub-insecure-hosts "work-wsl:9000/api/v4")
  (add-to-list 'ghub-insecure-hosts "work-wsl:9000")
  )

(provide 'my-git)
