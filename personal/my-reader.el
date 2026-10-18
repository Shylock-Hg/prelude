;;; -*- lexical-binding: t -*-

(require 'my-vendor)
(require 'use-package)

;; Update deliberately after running the graphical reader smoke test.
(defconst my-reader-revision "3dddbef84e275d5e800641829d128c348b712a8d"
  "Pinned emacs-reader commit used by interactive startup and GUI CI.")

;; The reader is a GUI document reader whose native module is built against
;; MuPDF.  Skip it entirely in noninteractive (batch/CI) sessions.
(unless noninteractive
  (defvar my-reader-fresh-installed (my-vendor-install-git "codeberg.org" "divyaranjan" "emacs-reader" my-reader-revision))

  (defvar my-reader-dir (my-vendor-dest "divyaranjan" "emacs-reader"))

  (when (eq my-reader-fresh-installed t)
    (message "Compiling emacs-reader...")
    (let ((ec (call-process "make" nil nil nil "-j8" "-C" my-reader-dir "all")) )
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
    ))

(provide 'my-reader)
