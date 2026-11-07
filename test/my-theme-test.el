;;; my-theme-test.el --- Theme startup regressions -*- lexical-binding: t -*-

;; Follow the actual recursive personal preload and UI initialization so the
;; optional Ef configuration cannot silently rejoin the default startup path.

(require 'ert)
(require 'cl-lib)
(require 'seq)

(defconst my-theme-test--repo-root
  (expand-file-name ".."
                    (file-name-directory
                     (or load-file-name buffer-file-name)))
  "Repository root for this test file.")

(defconst my-theme-test--preload-dir
  (expand-file-name "personal/preload" my-theme-test--repo-root)
  "Prelude's personal preload directory.")

(defconst my-theme-test--ef-module
  (expand-file-name "my-theme-ef-day.el.disabled" my-theme-test--preload-dir)
  "Retained Ef configuration that must remain outside automatic preloading.")

;; Keep the unrelated preload side effects isolated from these tests.
(defvar compile-angel-excluded-files nil)
(defun compile-angel-on-load-mode (&optional _argument) nil)
(provide 'compile-angel)

(defun my-theme-test--preload-files ()
  "Return the files selected by Prelude's real personal preload loader."
  (directory-files-recursively my-theme-test--preload-dir "^[^#\.].*el$"))

(defun my-theme-test--configure ()
  "Prepare a minimal startup environment for the theme tests."
  (dolist (directory '("core" "personal" "personal/preload"))
    (add-to-list 'load-path
                 (expand-file-name directory my-theme-test--repo-root)))
  (require 'use-package)
  (setq use-package-ensure-function (lambda (&rest _) t)
        use-package-verbose nil)
  ;; Isolate package installation from the preload itself.
  (fset 'package-initialize (lambda (&rest _) nil)))

(defun my-theme-test--load-auto-startup ()
  "Load the preload files and UI initialization as ordinary startup does."
  (my-theme-test--configure)
  (mapc #'load (my-theme-test--preload-files))
  (require 'prelude-custom)
  (require 'prelude-ui))

(defun my-theme-test--ef-takeover-p ()
  "Return non-nil when the Ef takeover mode is enabled."
  (and (boundp 'ef-themes-take-over-modus-themes-mode)
       (symbol-value 'ef-themes-take-over-modus-themes-mode)))

(defun my-theme-test--modus-theme-p (theme)
  "Return non-nil when THEME belongs to the Modus collection."
  (memq theme modus-themes-items))

(defun my-theme-test--ef-theme-p (theme)
  "Return non-nil when THEME belongs to the Ef collection."
  (and (featurep 'ef-themes) (memq theme ef-themes-items)))

(ert-deftest my-theme-test-auto-preload-keeps-modus-only ()
  (my-theme-test--load-auto-startup)
  (should-not (member my-theme-test--ef-module
                      (my-theme-test--preload-files)))
  (should (file-exists-p my-theme-test--ef-module))
  (should (equal custom-enabled-themes '(modus-operandi)))
  (should-not (my-theme-test--ef-takeover-p))
  (should-not (featurep 'ef-themes))
  (should (eq (key-binding (kbd "<f5>")) 'modus-themes-rotate))
  (should (eq (key-binding (kbd "C-<f5>")) 'modus-themes-select))
  (should (eq (key-binding (kbd "M-<f5>")) 'modus-themes-load-random))
  (let ((themes (modus-themes-get-themes)))
    (should (memq 'modus-operandi themes))
    (should (seq-every-p #'my-theme-test--modus-theme-p themes))
    (should-not (seq-some #'my-theme-test--ef-theme-p themes)))
  ;; <f5> rotates through the Modus collection, not the Ef collection.
  (let (loaded)
    (cl-letf (((symbol-function 'modus-themes-load-theme)
               (lambda (theme &optional _hook) (setq loaded theme))))
      (call-interactively (key-binding (kbd "<f5>")))
      (should (my-theme-test--modus-theme-p loaded))
      (should-not (my-theme-test--ef-theme-p loaded))))
  ;; C-<f5> prompts with the Modus collection.
  (let (loaded prompted)
    (cl-letf (((symbol-function 'modus-themes-select-prompt)
               (lambda (&rest _)
                 (setq prompted (modus-themes-get-themes))
                 'modus-vivendi))
              ((symbol-function 'modus-themes-load-theme)
               (lambda (theme &optional _hook) (setq loaded theme))))
      (call-interactively (key-binding (kbd "C-<f5>")))
      (should (eq loaded 'modus-vivendi))
      (should (memq 'modus-operandi prompted))
      (should (seq-every-p #'my-theme-test--modus-theme-p prompted))
      (should-not (seq-some #'my-theme-test--ef-theme-p prompted))))
  ;; M-<f5> chooses at random from the Modus collection.
  (let (loaded)
    (cl-letf (((symbol-function 'modus-themes-load-theme)
               (lambda (theme &optional _hook) (setq loaded theme)))
              ((symbol-function 'random) (lambda (_limit) 0)))
      (call-interactively (key-binding (kbd "M-<f5>")))
      (should (my-theme-test--modus-theme-p loaded))
      (should-not (my-theme-test--ef-theme-p loaded)))))

(ert-deftest my-theme-test-explicit-ef-load-works ()
  (my-theme-test--configure)
  ;; Installed packages autoload this mode before the retained module's :init
  ;; block runs, so mimic that autoload in the isolated test environment.
  (autoload 'ef-themes-take-over-modus-themes-mode "ef-themes" nil t)
  (load-file my-theme-test--ef-module)
  (should (featurep 'my-theme-ef-day))
  (should (featurep 'ef-themes))
  (should (my-theme-test--ef-takeover-p))
  (should (equal custom-enabled-themes '(ef-melissa-light)))
  (should (eq (key-binding (kbd "<f5>")) 'modus-themes-rotate))
  (should (eq (key-binding (kbd "C-<f5>")) 'modus-themes-select))
  (should (eq (key-binding (kbd "M-<f5>")) 'modus-themes-load-random))
  (let ((themes (modus-themes-get-themes)))
    (should (memq 'ef-melissa-light themes))
    (should (seq-every-p #'my-theme-test--ef-theme-p themes))
    (should-not (seq-some #'my-theme-test--modus-theme-p themes)))
  (let (loaded)
    (cl-letf (((symbol-function 'modus-themes-load-theme)
               (lambda (theme &optional _hook) (setq loaded theme))))
      (call-interactively (key-binding (kbd "<f5>")))
      (should (my-theme-test--ef-theme-p loaded)))))

;;; my-theme-test.el ends here
