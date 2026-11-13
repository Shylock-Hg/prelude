;;; my-company.el --- Personal Company configuration -*- lexical-binding: t -*-

;;; Commentary:

;; Resolve child-frame popup commands using the source buffer's keymaps.

;;; Code:

(defun my-company-childframe-command (original &rest arguments)
  "Call ORIGINAL with ARGUMENTS and resolve keys in the parent window.
Company redirects commands from its child frame in a pre-command hook,
after Emacs has already looked up the key in the popup buffer.  Resolve
the key again after redirection so the parent buffer's bindings apply,
including Evil's insert-state bindings."
  (let ((window (selected-window)))
    (apply original arguments)
    (unless (eq window (selected-window))
      (setq this-command (or (key-binding (this-command-keys-vector))
                             'undefined)))))

(with-eval-after-load 'company-childframe
  (advice-add 'company-childframe--pre-command :around
              #'my-company-childframe-command))

(provide 'my-company)
;;; my-company.el ends here
