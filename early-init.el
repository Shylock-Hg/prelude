;;; early-init.el --- Early Init File -*- no-byte-compile: t; lexical-binding: t; -*-

;; Emacs 27 and later load this file automatically during startup.

;; Ensure Emacs loads the most recent byte-compiled files.
(setq load-prefer-newer t)

;; Make Emacs Native-compile .elc files asynchronously by setting
;; `native-comp-jit-compilation' to t.
(setq native-comp-jit-compilation t)
(setq native-comp-deferred-compilation native-comp-jit-compilation)  ; Deprecated

;; Prelude activates packages after selecting its own package-user-dir.
;; Avoid activating the default directory first (and scanning packages twice).
(setq package-enable-at-startup nil)

;; Keep the normal runtime GC policy, but avoid collections while loading init.
;; The original limits are restored when startup completes.
(defvar prelude--startup-gc-cons-threshold gc-cons-threshold)
(defvar prelude--startup-gc-cons-percentage gc-cons-percentage)
(setq gc-cons-threshold (* 128 1024 1024)
      gc-cons-percentage 0.6)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold prelude--startup-gc-cons-threshold
                  gc-cons-percentage prelude--startup-gc-cons-percentage)))

;; To profile startup, run PRELUDE_PROFILE_STARTUP=1 emacs, then invoke
;; M-x prelude-startup-profile-report. The report sorts inclusive file load
;; times from slowest to fastest; nested loads overlap, so do not sum the rows.
;; Profiling stops at `emacs-startup-hook' and is disabled unless explicitly
;; requested. Compare several warm launches with the same installed packages
;; and modules; first-run package downloads are not representative of normal
;; startup.
(defvar prelude-startup-load-times nil
  "Inclusive startup load times as (FILE . SECONDS) entries.")

(defvar prelude--startup-profile-context-depth 0
  "Number of high-level profiling wrappers currently active.")

(defvar prelude--startup-profile-autoload-advice nil
  "Alist of autoload symbols and their profiling wrappers.")

(defconst prelude--startup-profile-advice
  '((load . prelude--profile-startup-load)
    (require . prelude--profile-startup-require)
    (load-with-code-conversion . prelude--profile-startup-load-with-code-conversion)
    (autoload . prelude--profile-startup-autoload-declaration)
    (autoload-do-load . prelude--profile-startup-autoload-load))
  "Functions advised and their startup profiling advice.")

(defun prelude--startup-profile-record (file start)
  "Record FILE's inclusive load time since START."
  (push (cons file (float-time (time-subtract (current-time) start)))
        prelude-startup-load-times))

(defmacro prelude--startup-profile-context (&rest body)
  "Run BODY as a high-level load operation and return its value."
  (declare (indent 0) (debug t))
  `(let ((prelude--startup-profile-context-depth
          (1+ prelude--startup-profile-context-depth)))
     ,@body))

(defun prelude--startup-profile-require-file (feature filename)
  "Return the file loaded by `require' for FEATURE or FILENAME."
  (or (and filename (locate-library filename))
      (locate-library (symbol-name feature))
      filename
      (symbol-name feature)))

(defun prelude--startup-profile-autoload-file (file)
  "Return FILE's resolved library path when possible."
  (or (and (stringp file) (locate-library file))
      file))

(defun prelude--profile-startup-load (original file &rest args)
  "Time ORIGINAL loading FILE with ARGS, including failed loads."
  (let ((start (current-time)))
    (prelude--startup-profile-context
      (unwind-protect
          (apply original file args)
        (prelude--startup-profile-record file start)))))

(defun prelude--profile-startup-require (original feature &optional filename noerror)
  "Time ORIGINAL requiring FEATURE from FILENAME with NOERROR.
`require' bypasses the Lisp `load' function for byte-compiled files."
  (if (featurep feature)
      (funcall original feature filename noerror)
    (let ((start (current-time))
          (file (prelude--startup-profile-require-file feature filename)))
      (prelude--startup-profile-context
        (unwind-protect
            (funcall original feature filename noerror)
          (prelude--startup-profile-record file start))))))

(defun prelude--profile-startup-load-with-code-conversion (original file &rest args)
  "Time ORIGINAL loading FILE with ARGS when no high-level wrapper is active.
`require' and autoload dispatch also use this path for source files."
  (if (> prelude--startup-profile-context-depth 0)
      (apply original file args)
    (let ((start (current-time)))
      (unwind-protect
          (apply original file args)
        (prelude--startup-profile-record file start)))))

(defun prelude--profile-startup-autoload-load (original fundef &rest args)
  "Time ORIGINAL loading autoload FUNDEF with ARGS."
  (if (not (autoloadp fundef))
      (apply original fundef args)
    (let ((start (current-time))
          (file (prelude--startup-profile-autoload-file (nth 1 fundef))))
      (prelude--startup-profile-context
        (unwind-protect
            (apply original fundef args)
          (prelude--startup-profile-record file start))))))

(defun prelude--startup-profile-remove-autoload (symbol)
  "Remove SYMBOL's profiling wrapper, restoring its autoload definition."
  (let ((entry (assq symbol prelude--startup-profile-autoload-advice)))
    (when entry
      (when (eq (symbol-function symbol) (nth 2 entry))
        (fset symbol (nth 1 entry)))
      (setq prelude--startup-profile-autoload-advice
            (assq-delete-all symbol
                             prelude--startup-profile-autoload-advice)))))

(defun prelude--startup-profile-resolve-autoload (symbol fundef)
  "Resolve autoload SYMBOL from FUNDEF and return its function value."
  (let ((resolved (autoload-do-load fundef symbol))
        (entry (assq symbol prelude--startup-profile-autoload-advice)))
    ;; `autoload-do-load' usually replaces the symbol already.  Ensure later
    ;; calls bypass the wrapper even if it did not.
    (when (and entry
               (eq (symbol-function symbol) (nth 2 entry)))
      (fset symbol resolved))
    resolved))

(defun prelude--startup-profile-instrument-autoload (symbol)
  "Instrument SYMBOL if it currently has an autoload definition.
Only the autoload resolution is timed; the resolved function body is not.
Keymap autoloads are left untouched because they are loaded as variables."
  (let ((fundef (and (fboundp symbol) (symbol-function symbol))))
    (when (and (autoloadp fundef)
               (not (eq (nth 4 fundef) 'keymap)))
      (prelude--startup-profile-remove-autoload symbol)
      (let* ((file (prelude--startup-profile-autoload-file (nth 1 fundef)))
             (wrapper
              (if (memq (nth 4 fundef) '(macro t))
                  (cons 'macro
                        (lambda (&rest args)
                          (let ((resolved
                                 (prelude--startup-profile-resolve-autoload
                                  symbol fundef)))
                            (apply (if (eq (car-safe resolved) 'macro)
                                       (cdr resolved)
                                     resolved)
                                   args))))
                (if (nth 3 fundef)
                    (lambda (&rest args)
                      (interactive)
                      (let ((resolved
                             (prelude--startup-profile-resolve-autoload
                              symbol fundef)))
                        (if (called-interactively-p 'any)
                            (call-interactively resolved)
                          (apply resolved args))))
                  (lambda (&rest args)
                    (apply (prelude--startup-profile-resolve-autoload
                            symbol fundef)
                           args))))))
        (push (list symbol fundef wrapper file)
              prelude--startup-profile-autoload-advice)
        (fset symbol wrapper)))))

(defun prelude--startup-profile-instrument-autoloads ()
  "Instrument all currently defined autoloads."
  (mapatoms (lambda (symbol)
              (when (autoloadp (symbol-function symbol))
                (prelude--startup-profile-instrument-autoload symbol)))))

(defun prelude--profile-startup-autoload-declaration (original symbol &rest args)
  "Call ORIGINAL to define autoload SYMBOL with ARGS, then instrument it."
  (prog1 (apply original symbol args)
    (when (autoloadp (symbol-function symbol))
      (prelude--startup-profile-instrument-autoload symbol))))

(defun prelude--startup-profile-start ()
  "Install startup profiling instrumentation."
  (dolist (entry prelude--startup-profile-advice)
    (advice-remove (car entry) (cdr entry))
    (advice-add (car entry) :around (cdr entry)))
  (prelude--startup-profile-instrument-autoloads))

(defun prelude--startup-profile-stop ()
  "Remove startup profiling instrumentation."
  (dolist (entry prelude--startup-profile-advice)
    (advice-remove (car entry) (cdr entry)))
  (dolist (entry prelude--startup-profile-autoload-advice)
    (when (eq (symbol-function (car entry)) (nth 2 entry))
      (fset (car entry) (nth 1 entry))))
  (setq prelude--startup-profile-autoload-advice nil
        prelude--startup-profile-context-depth 0))

(defun prelude-startup-profile-report ()
  "Display startup load timings, slowest first."
  (interactive)
  (with-output-to-temp-buffer "*Prelude Startup Profile*"
    (princ "Inclusive load times (nested loads overlap):\n\n")
    (dolist (entry (sort (copy-sequence prelude-startup-load-times)
                         (lambda (a b) (> (cdr a) (cdr b)))))
      (princ (format "%9.3f ms  %s\n" (* 1000 (cdr entry)) (car entry))))))

(when (equal (getenv "PRELUDE_PROFILE_STARTUP") "1")
  (prelude--startup-profile-start)
  (add-hook 'emacs-startup-hook
            (lambda ()
              (prelude--startup-profile-stop)
              (message "[Prelude] Startup: %s; %d garbage collections. Run M-x prelude-startup-profile-report for load timings."
                       (emacs-init-time) gcs-done))))
