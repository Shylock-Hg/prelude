;;; my-theme-test.el --- Theme startup regressions -*- lexical-binding: t -*-

;;; Commentary:

;; Exercise the theme through Prelude's startup entrypoint and check optional
;; Ef loading separately.

;;; Code:

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
  (expand-file-name "personal/my-theme-ef-day.el.disabled" my-theme-test--repo-root)
  "Retained Ef configuration for explicit loading.")

;; Keep the unrelated preload side effects isolated from these tests.
(defvar compile-angel-excluded-files nil)
(defun compile-angel-on-load-mode (&optional _argument)
  "Stub compile-angel's global mode for isolated startup.")
(provide 'compile-angel)

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

(defvar prelude-theme)
(defvar prelude-vendor-dir)

(defun my-theme-test--load-auto-startup ()
  "Run Prelude startup with unrelated packages and modules stubbed."
  (my-theme-test--configure)
  (let* ((user-emacs-directory (make-temp-file "my-theme-test-" t))
         (prelude-vendor-dir user-emacs-directory)
         (real-require (symbol-function 'require))
         (real-load (symbol-function 'load)))
    (unwind-protect
        (cl-letf (((symbol-function 'require)
                   (lambda (feature &rest args)
                     (pcase feature
                       ('prelude-packages
                        (should-not (featurep 'my-theme))
                        (should-not custom-enabled-themes)
                        feature)
                       ('prelude-core
                        (should (equal custom-enabled-themes
                                       (and prelude-theme (list prelude-theme))))
                        feature)
                       ((or 'prelude-mode 'prelude-editor 'prelude-global-keybindings
                            'prelude-linux 'prelude-macos 'prelude-wsl 'prelude-windows)
                        feature)
                       (_ (apply real-require feature args)))))
                  ((symbol-function 'load)
                   (lambda (file &rest args)
                     (unless (member (file-name-nondirectory file)
                                     '("prelude-modules.el" "my-modules.el"))
                       (apply real-load file args))))
                  ((symbol-function 'prelude-eval-after-init) #'ignore))
          (load (expand-file-name "init.el" my-theme-test--repo-root)))
      (delete-directory user-emacs-directory t))))

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

(ert-deftest my-theme-test-startup-enables-modus-only ()
  (my-theme-test--load-auto-startup)
  (should (featurep 'my-theme))
  (should-not (directory-files-recursively my-theme-test--preload-dir
                                           "^my-theme-.*\\.el\\'"))
  (should (file-exists-p my-theme-test--ef-module))
  (should (equal custom-enabled-themes '(modus-operandi)))
  (should-not (my-theme-test--ef-takeover-p))
  (should-not (featurep 'ef-themes))
  (should (eq (key-binding (kbd "<f5>")) 'modus-themes-rotate))
  (should (eq (key-binding (kbd "C-<f5>")) 'modus-themes-select))
  (should (eq (key-binding (kbd "M-<f5>")) 'modus-themes-load-random))
  ;; Batch frames report monochrome. Match color face specs while checking
  ;; that a face declared after startup receives the active theme's settings.
  (should-not (facep 'company-tooltip))
  (let ((display-type (frame-parameter nil 'display-type)))
    (unwind-protect
        (cl-letf (((symbol-function 'display-color-cells) (lambda (&rest _) 256)))
          (set-frame-parameter nil 'display-type 'color)
          (defface company-tooltip '((t :inherit default))
            "Stand-in for Company's late face declaration.")
          (should (eq (face-attribute 'company-tooltip :inherit)
                      'modus-themes-fixed-pitch)))
      (set-frame-parameter nil 'display-type display-type)))
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

(ert-deftest my-theme-test-startup-honors-theme-override ()
  (let ((prelude-theme nil))
    (my-theme-test--load-auto-startup)
    (should (featurep 'my-theme))
    (should-not custom-enabled-themes)))

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
