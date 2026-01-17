;;; -*- lexical-binding: t -*-

(require 'prelude-packages)

(prelude-require-package 'multiple-cursors)

(require 'multiple-cursors)

(with-eval-after-load 'evil
  (define-key evil-visual-state-map (kbd "I") #'mc/edit-beginnings-of-lines)
  (define-key evil-visual-state-map (kbd "A") #'mc/edit-ends-of-lines)
      )

(provide 'my-multiple-cursors)
