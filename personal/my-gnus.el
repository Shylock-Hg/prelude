;;; -*- lexical-binding: t -*-

(setq user-full-name "Shylock Hg")
(setq user-mail-address "tcath2s@icloud.com")

;; ========== （IMAP）==========
(setq gnus-select-method
      '(nnimap "icloud"
               (nnimap-address "imap.mail.me.com")
               (nnimap-server-port 993)
               (nnimap-stream ssl)
               (nnimap-authinfo-file "~/.authinfo")))

;; ========== （SMTP）==========
(setq smtpmail-smtp-server "smtp.mail.me.com")
(setq smtpmail-smtp-service 587)
;;(setq settpmail-stream-type 'starttls)  ; iCloud use STARTTLS
(setq send-mail-function 'smtpmail-send-it)
(setq message-send-mail-function 'smtpmail-send-it)

(defalias 'email-new 'gnus-msg-mail
  )
(defalias 'email-attach-file 'mml-attach-file)
(defalias 'email-send 'message-send-and-exit)

(provide 'my-gnus)
