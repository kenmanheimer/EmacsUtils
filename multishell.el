;;; multishell.el --- manage interaction with multiple local and remote shells

;; Copyright (C) 1999-2016 Free Software Foundation, Inc. and Ken Manheimer

;; Author: Ken Manheimer <ken.manheimer@gmail.com>
;; Version: 1.0.4
;; Created: 1999 -- first public availability
;; Keywords: processes
;; URL: https://github.com/kenmanheimer/EmacsUtils
;;
;;; Commentary:
;;
;; Easily use and manage multiple shell buffers, including remote shells.
;; Fundamentally, multishell is the function `multishell-pop-to-shell' -
;; a la `pop-to-buffer' - plus a keybinding. Together, they enable you to:
;;
;; * Get to the input point from wherever you are in a shell buffer,
;; * ... or to a shell buffer if you're not currently in one.
;; * Use universal arguments to launch and choose among alternate shell buffers,
;; * ... and select which is default.
;; * Append a path to a new shell name to launch a shell in that directory,
;; * ... and use a path with Emacs tramp syntax to launch a remote shell.
;;
;; Customize-group `multishell` to select and activate a keybinding and set
;; various behaviors.
;;
;; See the multishell-pop-to-shell docstring for details.
;;
;;; Change Log:
;;
;; 2016-01-02 Ken Manheimer - working on this in public, but not yet released.
;;
;;; TODO:
;;
;; * Fix operation given local path without specified name
;; * Preserveable (savehist) history that associates names with paths
;;   - Using an association list between names and paths
;;   - Searched for search backwards/forwards on isearch-like M-r/M-s bindings
;;     - *Not* searched for regular completion
;;   - Editible
;;     - During confirmation for new buffers - to use historical one
;;     - Or with minibuffer setup created key binding (isearch-like) M-e
;;       - M-e in empty initial provides completion on historicals
;;     - User can edit the entire path, changing the association
;;     - New association overrides previous
;;     - Deleting path removes association and history entry
;;   - Tracks buffer name changes
;;     - Using buffer-list-update-hook
;; * Customize activation of savehist
;;   - Customize entry has warning about activating savehist
;;   - Adds the name/path association list to savehist-additional-variables
;;   - Activates savehist, if inactive

;;; Code:

(require 'comint)
(require 'shell)

(defgroup multishell nil
  "Allout extension that highlights outline structure graphically.

Customize `allout-widgets-auto-activation' to activate allout-widgets
with allout-mode."
  :group 'shell)

(defcustom multishell-command-key "\M- "
  "The key to use if `multishell-activate-command-key' is true.

You can instead manually bind `multishell-pop-to-shell` using emacs
lisp, eg: (global-set-key \"\\M- \" 'multishell-pop-to-shell)."
  :type 'key-sequence
  :group 'multishell)

(defvar multishell--responsible-for-command-key nil
  "Multishell internal.")
(defun multishell-activate-command-key-setter (symbol setting)
  "Implement `multishell-activate-command-key' choice."
  (set-default 'multishell-activate-command-key setting)
  (when (or setting multishell--responsible-for-command-key)
    (multishell-implement-command-key-choice (not setting))))
(defun multishell-implement-command-key-choice (&optional unbind)
  "If settings dicate, implement binding of multishell command key.

If optional UNBIND is true, globally unbind the key.

* `multishell-activate-command-key' - Set this to get the binding or not.
* `multishell-command-key' - The key to use for the binding, if appropriate."
  (cond (unbind
         (when (and (boundp 'multishell-command-key) multishell-command-key)
           (global-unset-key multishell-command-key)))
        ((not (and (boundp 'multishell-activate-command-key)
                   (boundp 'multishell-command-key)))
         nil)
        ((and multishell-activate-command-key multishell-command-key)
         (setq multishell--responsible-for-command-key t)
         (global-set-key multishell-command-key 'multishell-pop-to-shell))))

(defcustom multishell-activate-command-key nil
  "Set this to impose the `multishell-command-key' binding.

You can instead manually bind `multishell-pop-to-shell` using emacs
lisp, eg: (global-set-key \"\\M- \" 'multishell-pop-to-shell)."
  :type 'boolean
  :set 'multishell-activate-command-key-setter
  :group 'multishell)

;; Assert the customizations whenever the package is loaded:
(with-eval-after-load "multishell"
  (multishell-implement-command-key-choice))

(defcustom multishell-pop-to-frame nil
  "*If non-nil, jump to a frame already showing the shell, if another is.

Otherwise, disregard already-open windows on the shell if they're
in another frame, and open a new window on the shell in the
current frame.

\(Use `pop-up-windows' to change multishell other-buffer vs
current-buffer behavior.)"
  :type 'boolean
  :group 'multishell)

;; (defcustom multishell-persist-shell-names nil
;;   "Remember shell name/path associations across sessions. Note well:
;; This will activate minibuffer history persistence, in general, if it's not
;; already active."
;;   :type 'boolean
;;  :group 'shell)

(defvar multishell-name-path-assoc nil
  "Assoc list from name to path")

(defvar multishell-primary-name "*shell*"
  "Shell name to use for un-modified multishell-pop-to-shell buffer target.")
(defvar multishell-buffer-name-history nil
  "Distinct multishell-pop-to-shell completion history container.")
(defvar multishell-buffer-name-path-history nil
  "Another multishell-pop-to-shell completion history container,
including paths.")

;;;###autoload
(defun multishell-pop-to-shell (&optional arg)
  "Easily navigate to and within multiple shell buffers, local and remote.

Use universal arguments to launch and choose between alternate
shell buffers and to select which is default.  Append a path to
a new shell name to launch a shell in that directory, and use
Emacs tramp syntax to launch a remote shell.

Customize-group `multishell' to set up a key binding and tweak behaviors.

==== Basic operation:

 - If the current buffer is shell-mode (or shell-mode derived)
   buffer then focus is moved to the process input point.

   \(You can use a universal argument go to a different shell
   buffer when already in a buffer that has a process - see
   below.)

 - If not in a shell buffer (or with universal argument), go to a
   window that is already showing the (a) shell buffer, if any.

   In this case, the cursor is left in its prior position in the
   shell buffer. Repeating the command will then go to the
   process input point, per the first item in this list.

   We respect `pop-up-windows', so you can adjust it to set the
   other-buffer/same-buffer behavior.

 - Otherwise, start a new shell buffer, using the current
   directory as the working directory.

If a buffer with the resulting name exists and its shell process
was disconnected or otherwise stopped, it's resumed.

===== Universal arg to start and select between named shell buffers:

You can name alternate shell buffers to create or return to using
single or doubled universal arguments:

 - With a single universal argument, prompt for the buffer name
   to use (without the asterisks that shell mode will put around
   the name), defaulting to 'shell'.

   Completion is available.

   This combination makes it easy to start and switch between
   multiple shell buffers.

 - A double universal argument will prompt for the name *and* set
   the default to that name, so the target shell becomes the
   primary.

===== Select starting directory and remote host:

The shell buffer name you give to the prompt for a universal arg
can include an appended path. That will be used for the startup
directory. You can use tramp remote syntax to specify a remote
shell. If there is an element after a final '/', that's used for
the buffer name. Otherwise, the host, domain, or path is used.

For example:

* Use '/ssh:example.net:/' for a shell buffer on example.net named
  \"example.net\".
* '\#ex/ssh:example.net|sudo:root@example.net:/' for a root shell on 
  example.net named \"#ex\"."

;; I'm leaving the following out of the docstring for now because just
;; saving the buffer names, and not the paths, yields sometimes unwanted
;; behavior.

;; ===== Persisting your alternate shell buffer names and paths:

;; You can use emacs builtin SaveHist to preserve your alternate
;; shell buffer names and paths across emacs sessions. To do so,
;; customize the `savehist' group, and:

;; 1. Add `multishell-pop-to-shell-buffer-name-history' to Savehist Additional
;;    Variables.
;; 2. Activate Savehist Mode, if not already activated.
;; 3. Save.

  (interactive "P")

  (let* ((from-buffer (current-buffer))
         (from-buffer-is-shell (derived-mode-p 'shell-mode))
         (doublearg (equal arg '(16)))
         (target-name-and-path
          (multishell-derive-target-name-and-path
           (if arg
               (multishell-read-bare-shell-buffer-name
                (format "Shell buffer name [%s]%s "
                        (substring-no-properties
                         multishell-primary-name
                         1 (- (length multishell-primary-name) 1))
                        (if doublearg " <==" ":"))
                multishell-primary-name)
             multishell-primary-name)))
         (use-default-dir (cadr target-name-and-path))
         (target-shell-buffer-name (car target-name-and-path))
         (curr-buff-proc (get-buffer-process from-buffer))
         (target-buffer (if from-buffer-is-shell
                            from-buffer
                          (get-buffer target-shell-buffer-name)))
         inwin
         already-there)

    (when doublearg
      (setq multishell-primary-name target-shell-buffer-name))

    ;; Situate:

    (cond 

     ((and (or curr-buff-proc from-buffer-is-shell)
           (not arg)
           (eq from-buffer target-buffer)
           (not (eq target-shell-buffer-name (buffer-name from-buffer))))
      ;; In a shell buffer, but not named - stay in buffer, but go to end.
      (setq already-there t))

     ((string= (buffer-name) target-shell-buffer-name)
      ;; Already in the specified shell buffer:
      (setq already-there t))

     ((or (not target-buffer)
          (not (setq inwin
                     (multishell-get-visible-window-for-buffer target-buffer))))
      ;; No preexisting shell buffer, or not in a visible window:
      (pop-to-buffer target-shell-buffer-name pop-up-windows))

       ;; Buffer exists and already has a window - jump to it:
     (t (if (and multishell-pop-to-frame
                 inwin
                 (not (equal (window-frame (selected-window))
                             (window-frame inwin))))
            (select-frame-set-input-focus (window-frame inwin)))
        (if (not (string= (buffer-name (current-buffer))
                          target-shell-buffer-name))
            (pop-to-buffer target-shell-buffer-name t))))

    ;; We're in the buffer. Activate:

    (cond ((not (comint-check-proc (current-buffer)))
           (multishell-start-shell-in-buffer (buffer-name (current-buffer))
                                             use-default-dir))
          (use-default-dir
           (cd use-default-dir)))

    ;; If the destination buffer has a stopped process, resume it:
    (let ((process (get-buffer-process (current-buffer))))
      (if (and process (equal 'stop (process-status process)))
          (continue-process process)))
    (when (or already-there
             (equal (current-buffer) from-buffer))
      (goto-char (point-max))
      (and (get-buffer-process from-buffer)
           (goto-char (process-mark (get-buffer-process from-buffer)))))))

(defun multishell-get-visible-window-for-buffer (buffer)
  "Return visible window containing buffer."
  (catch 'got-a-vis
    (walk-windows
     (function (lambda (win)
                 (if (and (eq (window-buffer win) buffer)
                          (equal (frame-parameter
                                  (selected-frame) 'display)
                                 (frame-parameter
                                  (window-frame win) 'display)))
                     (throw 'got-a-vis win))))
     nil 'visible)
    nil))

(defun multishell-read-bare-shell-buffer-name (prompt default)
  "PROMPT for shell buffer name, sans asterisks.

Return the supplied name bracketed with the asterisks, or specified DEFAULT
on empty input."
  (let* ((candidates (append
                      (remq nil
                            (mapcar (lambda (buffer)
                                      (let ((name (buffer-name buffer)))
                                        (if (with-current-buffer buffer
                                              (derived-mode-p 'shell-mode))
                                            ;; Shell mode buffers.
                                            (if (> (length name) 2)
                                                ;; Strip asterisks.
                                                (substring name 1
                                                           (1- (length name)))
                                              name))))
                                    (buffer-list)))))
         (got (completing-read prompt
                               candidates ; COLLECTION
                               nil        ; PREDICATE
                               'confirm   ; REQUIRE-MATCH
                               nil        ; INITIAL-INPUT
                               'multishell-buffer-name-history ; HIST
                               )))
    (if (not (string= got "")) (multishell-bracket-asterisks got) default)))
(defun multishell-derive-target-name-and-path (path-ish)
  "Give tramp-style PATH-ISH, determine target name and default directory.

The name is the part of the string before the initial '/' slash,
if any. Otherwise, it's either the host-name, domain-name, final
directory name, or local host name. The path is everything
besides the string before the initial '/' slash.

Return them as a list (name dir), with dir nil if none given."
  (let (name (path "") dir)
    (cond ((string= path-ish "") (setq dir multishell-primary-name))
          ((string-match "^\\*\\([^/]*\\)\\(/.*/\\)\\(.*\\)\\*" path-ish)
           ;; We have a path, use it
           (let ((overt-name (match-string 1 path-ish))
                 (overt-path (match-string 2 path-ish))
                 (trailing-name (match-string 3 path-ish)))
             (if (string= overt-name "") (setq overt-name nil))
             (if (string= overt-path "") (setq overt-path nil))
             (if (string= trailing-name "") (setq trailing-name nil))
             (setq path (concat overt-path trailing-name))
             (setq name
                   (multishell-bracket-asterisks
                    (or overt-name
                        (if (file-remote-p path)
                            (let ((vec (tramp-dissect-file-name path)))
                              (or (tramp-file-name-host vec)
                                  (tramp-file-name-domain vec)
                                  (tramp-file-name-localname vec)
                                  trailing-name
                                  system-name))
                          (multishell-unbracket-asterisks
                           multishell-primary-name)))))))
          (t (setq name (multishell-bracket-asterisks path-ish))))
    (list name path)))

(defun multishell-bracket-asterisks (name)
  "Return a copy of name, ensuring it has an asterisk at the beginning and end."
  (if (not (string= (substring name 0 1) "*"))
      (setq name (concat "*" name)))
  (if (not (string= (substring name -1) "*"))
      (setq name (concat name "*")))
  name)
(defun multishell-unbracket-asterisks (name)
  "Return a copy of name, removing asterisks, if any, at beginning and end."
  (if (string= (substring name 0 1) "*")
      (setq name (substring name 1)))
  (if (string= (substring name -1) "*")
      (setq name (substring name 0 -1)))
  name)

(defun multishell-start-shell-in-buffer (buffer-name path)
  "Ensure a shell is started, with name NAME and PATH."
  ;; We work around shell-mode's bracketing of the buffer name, and do
  ;; some tramp-mode hygiene for remote connections.

  (let* ((buffer buffer-name)
         (prog (or explicit-shell-file-name
                   (getenv "ESHELL")
                   (getenv "SHELL")
                   "/bin/sh"))
         (name (file-name-nondirectory prog))
         (startfile (concat "~/.emacs_" name))
         (xargs-name (intern-soft (concat "explicit-" name "-args"))))
    (set-buffer buffer-name)
    (if (and path (not (string= path "")))
        (setq default-directory path))
    (when (and (file-remote-p default-directory)
               (derived-mode-p 'shell-mode)
               (not (comint-check-proc (current-buffer))))
      ;; We're returning to an already established but disconnected remote
      ;; shell, tidy it:
      (tramp-cleanup-connection
       (tramp-dissect-file-name default-directory 'noexpand)
       'keep-debug 'keep-password))
    ;; (cd default-directory) will reconnect a disconnected remote:
    (cd default-directory)
    (setq buffer (set-buffer (apply 'make-comint
                                    (multishell-unbracket-asterisks buffer-name)
                                    prog
                                    (if (file-exists-p startfile)
                                        startfile)
                                    (if (and xargs-name
                                             (boundp xargs-name))
                                        (symbol-value xargs-name)
                                      '("-i")))))
    (shell-mode)))

(provide 'multishell)

;;; multishell.el ends here
