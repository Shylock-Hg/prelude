;;; my-pilish-test.el --- Pilish startup regressions -*- lexical-binding: t; -*-

;;; Commentary:

;; Exercise package and Pi CLI installation guards without network access.

;;; Code:

(require 'ert)
(require 'cl-lib)

;; Avoid native-compiling trampolines for the primitives stubbed below.
(setq native-comp-enable-subr-trampolines nil)

;; Load the implementation without running startup installation or using npm.
(provide 'prelude-packages)
(let ((emacs-version "28.2"))
  (load "my-pilish" nil t))

(defun my-pilish-test-load (version treesit &optional pi-available)
  "Load the configuration for VERSION with TREESIT availability.
PI-AVAILABLE non-nil means the `pi' executable is already installed.
Return a plist describing installed packages, npm calls, and warnings."
  (let ((emacs-version version)
        installed
        npm-calls
        warnings
        (pi-found pi-available))
    (cl-letf (((symbol-function 'prelude-require-package)
               (lambda (package) (push package installed)))
              ((symbol-function 'treesit-available-p) (lambda () treesit))
              ((symbol-function 'executable-find)
               (lambda (program)
                 (cond
                  ((equal program "pi")
                   (and pi-found "/usr/local/bin/pi"))
                  ((equal program "npm") "/usr/local/bin/npm")
                  (t nil))))
              ((symbol-function 'call-process)
               (lambda (program _input _output _display &rest arguments)
                 (push (cons program arguments) npm-calls)
                 (setq pi-found t)
                 (insert "simulated npm output")
                 0))
              ((symbol-function 'display-warning)
               (lambda (type message &optional level _buffer-name)
                 (push (list type message level) warnings)))
              ((symbol-function 'message) (lambda (&rest _arguments) nil))
              ((symbol-function 'pilish) nil)
              ((symbol-function 'pi) nil))
      (let ((saved-features features))
        (unwind-protect
            (progn
              (provide 'prelude-packages)
              (load "my-pilish" nil t))
          (setq features saved-features)))
      (list :installed installed
            :npm-calls (nreverse npm-calls)
            :warnings (nreverse warnings)
            :pilish-autoload
            (autoloadp (symbol-function 'pilish))
            :pi-command (commandp 'pi)
            :pi-target (and (fboundp 'pi) (symbol-function 'pi))))))

(defun my-pilish-test-warning (warning)
  "Return the message from WARNING, checking that it is a plain warning."
  (should (eq (nth 2 warning) :warning))
  (nth 1 warning))

(ert-deftest my-pilish-supported-emacs-installs-lazy-command ()
  (let ((result (my-pilish-test-load "29.1" t t)))
    (should (equal (plist-get result :installed) '(pilish)))
    (should-not (plist-get result :npm-calls))
    (should-not (plist-get result :warnings))
    (should (plist-get result :pilish-autoload))
    (should (plist-get result :pi-command))
    (should (eq (plist-get result :pi-target) 'pilish))))

(ert-deftest my-pilish-supported-emacs-installs-missing-cli ()
  (let ((result (my-pilish-test-load "29.1" t nil)))
    (should (equal (plist-get result :installed) '(pilish)))
    (should (equal (plist-get result :npm-calls)
                   '(("/usr/local/bin/npm"
                      "install" "-g" "@earendil-works/pi-coding-agent"))))
    (should-not (plist-get result :warnings))))

(ert-deftest my-pilish-older-emacs-skips-installation ()
  (let ((result (my-pilish-test-load "28.2" t nil)))
    (should-not (plist-get result :installed))
    (should-not (plist-get result :npm-calls))
    (should-not (fboundp 'pi))
    (should-not (fboundp 'pilish))))

(ert-deftest my-pilish-without-tree-sitter-skips-installation ()
  (let ((result (my-pilish-test-load "29.1" nil nil)))
    (should-not (plist-get result :installed))
    (should-not (plist-get result :npm-calls))
    (should-not (fboundp 'pi))
    (should-not (fboundp 'pilish))))

(ert-deftest my-pilish-ensure-cli-skips-installed-executable ()
  (let (npm-called warning)
    (cl-letf (((symbol-function 'executable-find)
               (lambda (program)
                 (should (equal program "pi"))
                 "/usr/local/bin/pi"))
              ((symbol-function 'call-process)
               (lambda (&rest _arguments)
                 (setq npm-called t)))
              ((symbol-function 'display-warning)
               (lambda (&rest _arguments)
                 (setq warning t))))
      (should (my-pilish-ensure-cli))
      (should-not npm-called)
      (should-not warning))))

(ert-deftest my-pilish-ensure-cli-installs-missing-executable ()
  (let ((pi-available nil)
        calls
        messages)
    (cl-letf (((symbol-function 'executable-find)
               (lambda (program)
                 (cond
                  ((equal program "pi")
                   (and pi-available "/usr/local/bin/pi"))
                  ((equal program "npm") "/usr/local/bin/npm")
                  (t nil))))
              ((symbol-function 'call-process)
               (lambda (program _input _output _display &rest arguments)
                 (push (cons program arguments) calls)
                 (insert "installed package")
                 (setq pi-available t)
                 0))
              ((symbol-function 'message)
               (lambda (format-string &rest arguments)
                 (push (apply #'format format-string arguments) messages))))
      (should (my-pilish-ensure-cli))
      (should (equal calls
                     '(("/usr/local/bin/npm"
                        "install" "-g" "@earendil-works/pi-coding-agent"))))
      (should (equal messages
                     '("Installed the Pi CLI from @earendil-works/pi-coding-agent"))))))

(ert-deftest my-pilish-ensure-cli-reports-installation-failure ()
  (let (calls warning)
    (cl-letf (((symbol-function 'executable-find)
               (lambda (program)
                 (cond
                  ((equal program "pi") nil)
                  ((equal program "npm") "/usr/local/bin/npm")
                  (t nil))))
              ((symbol-function 'call-process)
               (lambda (program _input _output _display &rest arguments)
                 (push (cons program arguments) calls)
                 (insert "npm error simulated failure\n")
                 1))
              ((symbol-function 'display-warning)
               (lambda (type message &optional level _buffer-name)
                 (setq warning (list type message level)))))
      (should-not (my-pilish-ensure-cli))
      (should (equal calls
                     '(("/usr/local/bin/npm"
                        "install" "-g" "@earendil-works/pi-coding-agent"))))
      (should (string-match-p "Failed to install the Pi CLI"
                              (my-pilish-test-warning warning)))
      (should (string-match-p "status 1"
                              (my-pilish-test-warning warning)))
      (should (string-match-p "npm error simulated failure"
                              (my-pilish-test-warning warning))))))

(ert-deftest my-pilish-ensure-cli-reports-missing-npm ()
  (let (npm-called warning)
    (cl-letf (((symbol-function 'executable-find)
               (lambda (_program) nil))
              ((symbol-function 'call-process)
               (lambda (&rest _arguments)
                 (setq npm-called t)))
              ((symbol-function 'display-warning)
               (lambda (type message &optional level _buffer-name)
                 (setq warning (list type message level)))))
      (should-not (my-pilish-ensure-cli))
      (should-not npm-called)
      (should (string-match-p "npm.*not on `exec-path'"
                              (my-pilish-test-warning warning)))
      (should (string-match-p "npm install -g @earendil-works/pi-coding-agent"
                              (my-pilish-test-warning warning))))))

(ert-deftest my-pilish-ensure-cli-warns-when-installed-cli-is-not-found ()
  (let (warning)
    (cl-letf (((symbol-function 'executable-find)
               (lambda (program)
                 (cond
                  ((equal program "pi") nil)
                  ((equal program "npm") "/usr/local/bin/npm")
                  (t nil))))
              ((symbol-function 'call-process)
               (lambda (&rest _arguments)
                 (insert "installed package")
                 0))
              ((symbol-function 'message) (lambda (&rest _arguments) nil))
              ((symbol-function 'display-warning)
               (lambda (type message &optional level _buffer-name)
                 (setq warning (list type message level)))))
      (should (my-pilish-ensure-cli))
      (should (string-match-p "still not on `exec-path'"
                              (my-pilish-test-warning warning))))))

(ert-deftest my-pilish-ensure-cli-reports-process-error ()
  (let (warning)
    (cl-letf (((symbol-function 'executable-find)
               (lambda (program)
                 (cond
                  ((equal program "pi") nil)
                  ((equal program "npm") "/usr/local/bin/npm")
                  (t nil))))
              ((symbol-function 'call-process)
               (lambda (&rest _arguments)
                 (error "Simulated npm process failure")))
              ((symbol-function 'display-warning)
               (lambda (type message &optional level _buffer-name)
                 (setq warning (list type message level)))))
      (should-not (my-pilish-ensure-cli))
      (should (string-match-p "Simulated npm process failure"
                              (my-pilish-test-warning warning))))))


(provide 'my-pilish-test)
;;; my-pilish-test.el ends here
