;;; reader-gui-smoke.el --- Exercise the personal PDF reader under a GUI -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'subr-x)

(defconst prelude-reader-smoke-root
  (expand-file-name "../.." (file-name-directory load-file-name)))
(defvar prelude-reader-smoke-fit-called nil)
(defvar prelude-reader-smoke-force-failure nil)

(defun prelude-reader-smoke-assert (condition description)
  (unless condition
    (error "Reader GUI smoke assertion failed: %s" description)))

(defun prelude-reader-smoke-log (format-string &rest arguments)
  (let ((text (apply #'format format-string arguments)))
    (message "%s" text)
    (ignore-errors
      (write-region (concat text "\n") nil "/dev/stderr" nil 'silent))))

(defun prelude-reader-smoke--record-fit-to-width (&rest _arguments)
  (setq prelude-reader-smoke-fit-called t))

(defun prelude-reader-smoke-main ()
  (condition-case error-data
      (progn
        (when prelude-reader-smoke-force-failure
          (prelude-reader-smoke-assert nil "forced assertion failure"))
        (setq my-init-dir prelude-reader-smoke-root
              my-vendor-dir (expand-file-name "vendor" prelude-reader-smoke-root))
        (add-to-list 'load-path (expand-file-name "personal" prelude-reader-smoke-root))

        (prelude-reader-smoke-assert (not noninteractive)
                                     "Emacs must run interactively")
        (prelude-reader-smoke-assert (display-graphic-p)
                                     "Emacs must have a graphical frame")
        (prelude-reader-smoke-assert (image-type-available-p 'png)
                                     "Emacs must support PNG images")
        (prelude-reader-smoke-assert module-file-suffix
                                     "Emacs must support dynamic modules")

        ;; Load this source file directly so a byte-compiled file from the
        ;; preserved batch startup check cannot hide path/load regressions.
        (load-file (expand-file-name "personal/my-reader.el"
                                     prelude-reader-smoke-root))
        (prelude-reader-smoke-assert (featurep 'my-reader)
                                     "personal/my-reader.el must provide my-reader")
        (prelude-reader-smoke-assert (eq my-reader-fresh-installed t)
                                     "reader must be cloned and built on first install")
        (let* ((reader-dir (my-vendor-dest "divyaranjan" "emacs-reader"))
               (module-file (expand-file-name
                             (concat "render-core" module-file-suffix) reader-dir))
               (autoload-file (expand-file-name "reader-autoloads.el" reader-dir))
               (pdf-file (expand-file-name "docs/prelude-cheatsheet.pdf"
                                           prelude-reader-smoke-root))
               (upstream-revision
                (with-temp-buffer
                  (prelude-reader-smoke-assert
                   (zerop (call-process "git" nil t nil "-C" reader-dir
                                        "rev-parse" "HEAD"))
                   "could not read the cloned emacs-reader revision")
                  (string-trim (buffer-string))))
               (fit-called nil))
          (prelude-reader-smoke-log "Testing emacs-reader revision %s"
                                    upstream-revision)
          (prelude-reader-smoke-assert (featurep 'reader)
                                       "reader feature must be loaded")
          (prelude-reader-smoke-assert (featurep 'reader-autoloads)
                                       "generated reader autoloads must be loaded")
          (prelude-reader-smoke-assert (featurep 'render-core)
                                       "native render-core module must be loaded")
          (prelude-reader-smoke-assert (file-exists-p module-file)
                                       "render-core native module must exist")
          (prelude-reader-smoke-assert (file-exists-p autoload-file)
                                       "reader-autoloads.el must be generated")
          (prelude-reader-smoke-assert (file-readable-p pdf-file)
                                       "bundled PDF fixture must be readable")

          ;; `reader-default-fit' is height-based, so a call here proves the
          ;; personal reader hook called `reader-fit-to-width' during open.
          (advice-add 'reader-fit-to-width :before
                      #'prelude-reader-smoke--record-fit-to-width)
          (unwind-protect
              (reader-open-doc pdf-file)
            (advice-remove 'reader-fit-to-width
                           #'prelude-reader-smoke--record-fit-to-width))
          (setq fit-called prelude-reader-smoke-fit-called)
          (prelude-reader-smoke-assert fit-called
                                       "personal reader hook must fit pages to width")
          (prelude-reader-smoke-assert (eq major-mode 'reader-mode)
                                       "PDF must open in reader-mode")
          (prelude-reader-smoke-assert (= (reader-current-doc-pagenumber) 1)
                                       "first page must be displayed")
          (let* ((overlay (reader-current-doc-overlay))
                 (display (and overlay (overlay-get overlay 'display)))
                 (image-properties (and (consp display) (cdr display)))
                 (width (plist-get image-properties :width))
                 (height (plist-get image-properties :height)))
            (prelude-reader-smoke-assert
             (and (consp display) (eq (car display) 'image))
             "reader overlay must contain a rendered image")
            (prelude-reader-smoke-assert (and (numberp width) (> width 0))
                                         "rendered image width must be positive")
            (prelude-reader-smoke-assert (and (numberp height) (> height 0))
                                         "rendered image height must be positive")
            (prelude-reader-smoke-log "Rendered PDF first page at %sx%s"
                                      width height)))
        (prelude-reader-smoke-log "Reader GUI smoke passed")
        (kill-emacs 0))
    ((error quit)
     (prelude-reader-smoke-log "Reader GUI smoke failed: %s"
                               (error-message-string error-data))
     (let ((backtrace-text
            (with-temp-buffer
              (let ((standard-output (current-buffer)))
                (backtrace))
              (buffer-string))))
       (prelude-reader-smoke-log "%s" backtrace-text))
     (kill-emacs 1))))

(prelude-reader-smoke-main)

;;; reader-gui-smoke.el ends here
