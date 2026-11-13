;;; my-company-test.el --- Company command regressions -*- lexical-binding: t -*-
;;
;; Copyright © 2011-2025 Bozhidar Batsov
;;
;; Author: Bozhidar Batsov <bozhidar@batsov.com>
;; URL: https://github.com/bbatsov/prelude

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Verify key dispatch after Company child-frame command redirection.

;;; License:

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'evil)

;; Exercise the startup entrypoint while suppressing unrelated personal modules.
(defvar my-company-test-startup-state
  (let ((real-require (symbol-function 'require)))
    (cl-letf (((symbol-function 'require)
               (lambda (feature &optional filename noerror)
                 (when (eq feature 'my-company)
                   (funcall real-require feature filename noerror)))))
      (load "my-modules.el" nil t))
    (list (featurep 'my-company)
          (featurep 'company)
          (featurep 'company-childframe)
          (advice-member-p #'my-company-childframe-command
                           'company-childframe--pre-command)))
  "Workaround, Company, child-frame, and advice state after startup.")

(require 'company-childframe)

(ert-deftest my-company-startup-installs-advice-lazily ()
  "The personal entrypoint defers advice until Company child-frame loads."
  (should (equal my-company-test-startup-state '(t nil nil nil)))
  (should (advice-member-p #'my-company-childframe-command
                          'company-childframe--pre-command)))

(defun my-company-test-dispatch (state command key check)
  "Dispatch COMMAND for KEY from a popup to a parent in STATE, then CHECK."
  (save-window-excursion
    (let ((parent (generate-new-buffer " *company-test-parent*"))
          (popup (generate-new-buffer " *company-test-popup*"))
          (frame (selected-frame))
          (original-frame-parameter (symbol-function 'frame-parameter)))
      (unwind-protect
          (progn
            (switch-to-buffer parent)
            (evil-local-mode 1)
            (evil-change-state state)
            (insert "keep")
            (let ((popup-window (split-window-below)))
              (set-window-buffer popup-window popup)
              (select-window popup-window))
            (evil-local-mode 1)
            (evil-normal-state)
            (let ((this-command command))
              (cl-letf (((symbol-function 'this-command-keys-vector)
                         (lambda () key))
                        ((symbol-function 'frame-parameter)
                         (lambda (target parameter)
                           (pcase parameter
                             ('parent-frame frame)
                             ('posframe-parent-buffer (cons frame parent))
                             (_ (funcall original-frame-parameter
                                         target parameter))))))
                (company-childframe--pre-command)
                (funcall check parent popup this-command))))
        (kill-buffer parent)
        (kill-buffer popup)))))

(ert-deftest my-company-childframe-insert-u ()
  "A popup normal-state binding must insert text in the source buffer."
  (my-company-test-dispatch
   'insert 'evil-undo [?u]
   (lambda (parent _popup command)
     (should (eq (current-buffer) parent))
     (should (eq evil-state 'insert))
     (should (eq command 'self-insert-command))
     (let ((last-command-event ?u))
       (call-interactively command))
     (should (equal (buffer-string) "keepu")))))

(ert-deftest my-company-childframe-normal-u ()
  "Undo remains available in the source buffer's normal state."
  (my-company-test-dispatch
   'normal 'self-insert-command [?u]
   (lambda (parent _popup command)
     (should (eq (current-buffer) parent))
     (should (eq command 'evil-undo)))))

(ert-deftest my-company-childframe-wheel-stays-in-popup ()
  "Company's popup scrolling commands must not be redirected or rebound."
  (my-company-test-dispatch
   'insert 'company-childframe-wheel-up [wheel-down]
   (lambda (_parent popup command)
     (should (eq (current-buffer) popup))
     (should (eq command 'company-childframe-wheel-up)))))

(provide 'my-company-test)
;;; my-company-test.el ends here
