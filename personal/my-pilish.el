;;; my-pilish.el --- Pilish coding agent setup -*- lexical-binding: t; -*-

;;; Commentary:

;; Install the Emacs frontend and ensure the Pi CLI is available.  See
;; docs/pilish.md for authentication and first-run setup.

;;; Code:

(require 'prelude-packages)
(require 'subr-x)

(defconst my-pilish-cli-package "@earendil-works/pi-coding-agent"
  "The npm package that provides the Pi CLI.")

(defun my-pilish--install-cli ()
  "Install the Pi CLI with npm when it is missing.
Return non-nil when npm reports success.  Report a warning and return nil
when npm is unavailable, exits unsuccessfully, or cannot be started."
  (let ((npm (executable-find "npm")))
    (cond
     ((not npm)
      (display-warning
       'my-pilish
       (format "Cannot install the Pi CLI because `npm' is not on `exec-path'.  Install Node.js and run `npm install -g %s'."
               my-pilish-cli-package)
       :warning)
      nil)
     (t
      (condition-case err
          (with-temp-buffer
            (let ((status (call-process npm nil t nil
                                        "install" "-g"
                                        my-pilish-cli-package)))
              (if (and (integerp status) (zerop status))
                  (progn
                    (message "Installed the Pi CLI from %s"
                             my-pilish-cli-package)
                    t)
                (let ((output (string-trim (buffer-string))))
                  (display-warning
                   'my-pilish
                   (format "Failed to install the Pi CLI (status %s): %s"
                           status
                           (if (string-empty-p output)
                               "npm produced no output"
                             output))
                   :warning)
                  nil))))
        (error
         (display-warning
          'my-pilish
          (format "Failed to install the Pi CLI: %s"
                  (error-message-string err))
          :warning)
         nil))))))

(defun my-pilish-ensure-cli ()
  "Ensure the Pi CLI is available, installing it with npm when missing.
Return non-nil when `pi' was already available or npm installed it.
Installation failures are reported as warnings and do not abort startup."
  (or (and (executable-find "pi") t)
      (when (my-pilish--install-cli)
        (unless (executable-find "pi")
          (display-warning
           'my-pilish
           "The Pi CLI was installed but `pi' is still not on `exec-path'.  Restart Emacs or add npm's global bin directory to PATH."
           :warning))
        t)))

(when (and (version<= "29.1" emacs-version)
           (fboundp 'treesit-available-p)
           (treesit-available-p))
  (my-pilish-ensure-cli)
  (prelude-require-package 'pilish)
  (autoload 'pilish "pilish" nil t)
  (defalias 'pi 'pilish))

(provide 'my-pilish)
;;; my-pilish.el ends here
