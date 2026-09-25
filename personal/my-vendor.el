;;; -*- lexical-binding: t -*-

(require 'subr-x)

(defvar my-init-dir (or (and user-init-file (file-name-directory user-init-file))
                        (bound-and-true-p prelude-dir)
                        default-directory))
(defvar my-vendor-dir (expand-file-name "vendor" my-init-dir))

(defun my-vendor--validate-string (name value)
  "Return VALUE when it is a non-empty string, otherwise signal an error.
NAME describes the argument in the error message."
  (unless (and (stringp value) (> (length value) 0))
    (error "%s must be a non-empty string" name))
  value)

(defun my-vendor-dest (user repo)
  "Return the local vendor directory for USER's REPO."
  (my-vendor--validate-string "User" user)
  (my-vendor--validate-string "Repository" repo)
  (expand-file-name (concat user "/" repo) my-vendor-dir))

(defun my-vendor--clone (url staging)
  "Clone URL into STAGING, capturing Git output and reporting failures."
  (with-temp-buffer
    (let* ((status (call-process "git" nil t nil
                                 "clone" "--depth=1" url staging))
           (output (string-trim (buffer-string))))
      (unless (and (integerp status) (zerop status))
        (let ((status-description
               (cond
                ((integerp status)
                 (format "Git exited with status %d" status))
                ((stringp status) status)
                (t (format "Git returned unexpected status %S" status)))))
          (error "Git clone failed for %s: %s%s"
                 url status-description
                 (if (string-empty-p output)
                     ""
                   (concat "\n" output))))))))

(defun my-vendor--path-exists-p (path)
  "Return non-nil when PATH exists, including a dangling symbolic link."
  (or (file-exists-p path)
      (file-symlink-p path)))

(defun my-vendor-install-git (host user repo)
  "Clone HOST/USER/REPO into `my-vendor-dir' when it is not installed.

Clone into a temporary sibling directory and move it into place only after
Git succeeds.  Return t when a fresh clone is installed, or nil when the
destination is already a directory.  Failed and interrupted clones remove
only their own temporary staging directory."
  (my-vendor--validate-string "Host" host)
  (my-vendor--validate-string "User" user)
  (my-vendor--validate-string "Repository" repo)
  (let* ((url (concat "https://" host "/" user "/" repo ".git"))
         (dest (my-vendor-dest user repo)))
    (cond
     ((file-directory-p dest)
      nil)
     ((my-vendor--path-exists-p dest)
      (error "Vendor destination already exists: %s" dest))
     (t
      (let* ((parent (file-name-directory dest))
             (staging nil))
        (make-directory parent t)
        (setq staging
              (make-temp-file
               (expand-file-name
                (concat "." (file-name-nondirectory dest) "-clone-")
                parent)
               t))
        (unwind-protect
            (progn
              (my-vendor--clone url staging)
              (when (my-vendor--path-exists-p dest)
                (error "Vendor destination appeared during clone: %s" dest))
              ;; The default `rename-file' behavior refuses to replace a path
              ;; that appears after the check above, including directories.
              (rename-file staging dest)
              (message "Cloned vendor repository into %s" dest)
              t)
          (when (file-directory-p staging)
            (delete-directory staging t))))))))

(provide 'my-vendor)
