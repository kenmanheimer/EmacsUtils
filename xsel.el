;; xsel.el -- X copy and paste emacs region from emacs tty sessions, using xsel

;; TODO: Check alternative: http://emacs.stackexchange.com/a/819/9668

;; Copyright (C) 2015 Free Software Foundation, Inc. and Ken Manheimer

;; Author: Ken Manheimer <ken dot manheimer at gmail...>
;; Maintainer: Ken Manheimer <ken dot manheimer at gmail...>
;; Created: 1999 -- first public release
;; Keywords: copy, paste, X11
;; Website: https://github.com/kenmanheimer/EmacsUtils

;;; Commentary:
;;
;; If xsel is installed and DISPLAY is working, use `klm:xsel-copy' to copy
;; the region to the X clipboard and `klm:xsel-paste' to paste the contents
;; of the clipboard at point. (The advantage of the latter over regular X
;; mouse paste is `klm:xsel-paste' looks unitary, to emacs, rather than
;; the mouse paste's continuous, parsed/indented/auto-parenned/etc input.)


(defun klm:xsel-check-get-DISPLAY (&optional arg)
  "Ensure X DISPLAY is set, and prompt for it if not.

With universal argument, always prompt to set it, regardless.

Returns the resulting value for DISPLAY."
  (interactive "P")
  (when (or arg (not (getenv "DISPLAY")))
    (setenv "DISPLAY"
            (read-from-minibuffer "DISPLAY: "
                                  (or (getenv "DISPLAY") ":10.0"))))
  (getenv "DISPLAY")
  )

      (pbpaste)
      (putclip)
 )
(defvar klm:xsel-clip-command
  (cond ((eq system-type 'darwin) 
         (let ((xclip (executable-find "xclip")))
           (if xclip
               (list xclip "-i")
             "pbcopy")))
        ((eq system-type 'cygwin) (list (executable-find "putclip")))
        ;; Linux &c:
        (t (list (executable-find "xsel") "--input" "--clipboard")))
  "X clip command tailored for local conditions.")
(defvar klm:xsel-paste-command
  (cond ((eq system-type 'darwin) 
         (let ((xclip (executable-find "xclip")))
           (if xclip
               (list xclip "-o")
             "pbpaste")))
        ((eq system-type 'cygwin) (list (executable-find "getclip")))
        ;; Linux &c:
        (t (list (executable-find "xsel") "--output" "--clipboard")))
  "X clip command tailored for local conditions.")

(defun klm:xsel-copy (from to)
  "Place contents of region in X copy/paste buffer, using shell command.

With universal argument, prompt to set DISPLAY."

  (interactive "r")
  (when (klm:xsel-check-get-DISPLAY current-prefix-arg)
    ;(shell-command-on-region from to klm:xsel-clip-command)
    (apply 'call-process-region
     (append (list from to (car klm:xsel-clip-command) nil nil nil)
             (cdr klm:xsel-clip-command)))
    (deactivate-mark)
    ))

(defun klm:xsel-paste ()
  "Place contents of region in X copy/paste buffer, using shell command."
  (interactive "")
  (when (klm:xsel-check-get-DISPLAY current-prefix-arg)
    (shell-command (apply 'concat
                          (append (list (car klm:xsel-paste-command) " ")
                                  (cdr klm:xsel-paste-command)))
                   1)
    (exchange-point-and-mark)
    ))
