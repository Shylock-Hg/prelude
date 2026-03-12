;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'gptel-agent)

(use-package gptel-agent
  :config (gptel-agent-update))         ;Read files from agents directories

(provide 'my-gptel-agent)
