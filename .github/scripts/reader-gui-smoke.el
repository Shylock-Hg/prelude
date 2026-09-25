;;; reader-gui-smoke.el --- Exercise the personal PDF reader under a GUI -*- lexical-binding: t; -*-

(require 'subr-x)

(defconst prelude-ci-reader-root
  (expand-file-name "../.." (file-name-directory load-file-name)))
(defvar prelude-ci-reader-force-failure nil)
(defvar prelude-ci-reader-fit-called nil)

(defun prelude-ci-reader-assert (condition description)
  "Signal an error when CONDITION is false, with DESCRIPTION."
  (unless condition
    (error "Reader GUI smoke assertion failed: %s" description)))

(defun prelude-ci-reader--record-fit-to-width (&rest _arguments)
  "Record that the personal reader hook called `reader-fit-to-width'."
  (setq prelude-ci-reader-fit-called t))

(defun prelude-ci-reader--report (text)
  "Show TEXT and save it to the optional CI result file."
  (message "%s" text)
  (when-let ((result-file (getenv "PRELUDE_CI_READER_RESULT")))
    (with-temp-file result-file
      (insert text "\n"))))

(defun prelude-ci-reader-smoke ()
  "Build and exercise the personal PDF reader in this graphical Emacs."
  (condition-case error-data
      (progn
        (when-let ((result-file (getenv "PRELUDE_CI_READER_RESULT")))
          (when (file-exists-p result-file)
            (delete-file result-file)))
        (when prelude-ci-reader-force-failure
          (prelude-ci-reader-assert nil "forced assertion failure"))
        (setq my-init-dir prelude-ci-reader-root
              my-vendor-dir (expand-file-name "vendor" prelude-ci-reader-root))
        (add-to-list 'load-path (expand-file-name "personal" prelude-ci-reader-root))

        (prelude-ci-reader-assert (not noninteractive)
                                  "Emacs must run interactively")
        (prelude-ci-reader-assert (display-graphic-p)
                                  "Emacs must have a graphical frame")
        (prelude-ci-reader-assert (image-type-available-p 'png)
                                  "Emacs must support PNG images")
        (prelude-ci-reader-assert (and module-file-suffix
                                       (fboundp 'module-load))
                                  "Emacs must support dynamic modules")

        ;; `-Q' skips Prelude's load-prefer-newer setting. Prefer current Lisp
        ;; sources if this checkout contains byte-code from an older startup.
        (setq load-prefer-newer t)
        (require 'my-reader)
        (prelude-ci-reader-assert (eq my-reader-fresh-installed t)
                                  "emacs-reader must be freshly cloned and built")
        (let* ((reader-dir (my-vendor-dest "divyaranjan" "emacs-reader"))
               (module-file (expand-file-name
                             (concat "render-core" module-file-suffix) reader-dir))
               (autoload-file (expand-file-name "reader-autoloads.el" reader-dir))
               (pdf-file (expand-file-name "docs/prelude-cheatsheet.pdf"
                                           prelude-ci-reader-root))
               (upstream-revision
                (with-temp-buffer
                  (prelude-ci-reader-assert
                   (zerop (call-process "git" nil t nil "-C" reader-dir
                                        "rev-parse" "HEAD"))
                   "could not read the cloned emacs-reader revision")
                  (string-trim (buffer-string))))
               (reader-module (locate-library "render-core"))
               (rendered-dimensions nil))
          (message "Testing emacs-reader revision %s" upstream-revision)
          (prelude-ci-reader-assert (featurep 'reader)
                                    "reader feature must be loaded")
          (prelude-ci-reader-assert (featurep 'reader-autoloads)
                                    "generated reader autoloads must be loaded")
          (prelude-ci-reader-assert (featurep 'render-core)
                                    "native render-core module must be loaded")
          (prelude-ci-reader-assert (and reader-module
                                         (file-in-directory-p
                                          (file-truename reader-module)
                                          (file-truename reader-dir)))
                                    "render-core must load from the vendored reader")
          (prelude-ci-reader-assert (file-exists-p module-file)
                                    "render-core native module must exist")
          (prelude-ci-reader-assert (file-exists-p autoload-file)
                                    "reader-autoloads.el must be generated")
          (prelude-ci-reader-assert (file-readable-p pdf-file)
                                    "bundled PDF fixture must be readable")
          (dolist (function-name '(reader-open-doc reader-fit-to-width
                                   reader-dyn--load-doc))
            (prelude-ci-reader-assert (fboundp function-name)
                                      (format "function %s must be available"
                                              function-name)))

          ;; `reader-default-fit' is height-based, so this verifies that the
          ;; personal reader hook selected fit-to-width while opening the PDF.
          (advice-add 'reader-fit-to-width :before
                      #'prelude-ci-reader--record-fit-to-width)
          (unwind-protect
              (reader-open-doc pdf-file)
            (advice-remove 'reader-fit-to-width
                           #'prelude-ci-reader--record-fit-to-width))
          (prelude-ci-reader-assert prelude-ci-reader-fit-called
                                    "personal reader hook must fit pages to width")
          (prelude-ci-reader-assert (eq major-mode 'reader-mode)
                                    "PDF must open in reader-mode")
          (prelude-ci-reader-assert (= (reader-current-doc-pagenumber) 1)
                                    "first page must be displayed")
          (let* ((overlay (reader-current-doc-overlay))
                 (display (and overlay (overlay-get overlay 'display)))
                 (image-properties (and (consp display) (cdr display)))
                 (width (plist-get image-properties :width))
                 (height (plist-get image-properties :height)))
            (prelude-ci-reader-assert
             (and (consp display) (eq (car display) 'image))
             "reader overlay must contain a rendered image")
            (prelude-ci-reader-assert (and (numberp width) (> width 0))
                                      "rendered image width must be positive")
            (prelude-ci-reader-assert (and (numberp height) (> height 0))
                                      "rendered image height must be positive")
            (setq rendered-dimensions (cons width height)))
          (prelude-ci-reader--report
           (format "Reader GUI smoke passed: upstream %s; PDF first page rendered at %sx%s"
                   upstream-revision
                   (car rendered-dimensions)
                   (cdr rendered-dimensions))))
        (kill-emacs 0))
    ((error quit)
     (prelude-ci-reader--report
      (format "Reader GUI smoke failed: %s"
              (error-message-string error-data)))
     (backtrace)
     (kill-emacs 1))))

(prelude-ci-reader-smoke)

;;; reader-gui-smoke.el ends here
