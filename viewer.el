;;; viewer.el --- View-mode extension -*- lexical-binding: t; -*-

;; Copyright (C) 2009,2014,2016  rubikitch

;; Author: rubikitch <rubikitch@ruby-lang.org>
;; Keywords: view, extensions
;; URL: https://github.com/rubikitch/viewer/
;; Package-Requires: ((emacs "27.1"))

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; Viewer is view-mode extension. View-mode is finger-friendly than
;; normal editing because of many alphabetical commands. Let's use
;; view-mode more to protect our pinky.

;;; Commands:
;;
;; Below are complete command list:
;;
;;
;;; Customizable Options:
;;
;; Below are customizable option list:
;;
;;  `view-mode-by-default-regexp'
;;    *Regexp of file name to open by `view-mode'.
;;    default = nil
;;  `viewer-aggressive-minimum-size'
;;    *Minimum file size to enable aggressive view-mode.
;;    default = 100
;;  `viewer-aggressive-writable'
;;    *When non-nil, aggressive view-mode buffer is writable.
;;    default = t
;;  `viewer-modeline-color-unwritable'
;;    *Modeline color when file is not writable.
;;    default = "tomato"
;;  `viewer-modeline-color-view'
;;    *Modeline color for `view-mode'.
;;    default = "orange"

;; This package provides:
;; * specify files to open by `view-mode' by default.
;; * stay in `view-mode' in unwritable files.
;; * indicate `view-mode' by modeline color.
;; * override default `view-mode-map' for major modes.
;; * open ANY files by `view-mode' for enthusiasts.

;;; Installation:

;; Put viewer.el to your load-path.
;; The load-path is usually ~/elisp/.
;; It's set in your ~/.emacs like this:
;; (add-to-list 'load-path (expand-file-name "~/elisp"))
;;
;; And the following to your ~/.emacs startup file.
;;
;; (require 'viewer)
;; (viewer-stay-in-setup)
;; (setq viewer-modeline-color-unwritable "tomato"
;;       viewer-modeline-color-view "orange")
;; (viewer-change-modeline-color-setup)
;;
;; If you want to open any file by `view-mode', add the following:
;; (viewer-aggressive-setup 'force)
;;
;; Note that the command `view-mode' should be bound in easy-to-type
;; key.
;;
;; If you want to open any file matching a regexp, add the following:
;; (setq view-mode-by-default-regexp "/regexp-to-path")
;;
;; No need more.

;;; Customize:

;;
;; All of the above can customize by:
;;      M-x customize-group RET viewer RET
;;

;;; Tips:

;; Defining major-mode specific `view-mode' is useful.
;; See `define-overriding-view-mode-map'.
;;
;; [EVAL IT] (describe-function 'define-overriding-view-mode-map)


;;; Bug Report:
;;
;; If you have problem, send a bug report via M-x viewer-send-bug-report.
;; The step is:
;;  0) Setup mail in Emacs, the easiest way is:
;;       (setq user-mail-address "your@mail.address")
;;       (setq user-full-name "Your Full Name")
;;       (setq smtpmail-smtp-server "your.smtp.server.jp")
;;       (setq mail-user-agent 'message-user-agent)
;;       (setq message-send-mail-function 'message-smtpmail-send-it)
;;  1) Be sure to use the LATEST version of viewer.el.
;;  2) Enable debugger. M-x toggle-debug-on-error or (setq debug-on-error t)
;;  3) Use Lisp version instead of compiled one: (load "viewer.el")
;;  4) Do it!
;;  5) If you got an error, please do not close *Backtrace* buffer.
;;  6) M-x viewer-send-bug-report and M-x insert-buffer *Backtrace*
;;  7) Describe the bug using a precise recipe.
;;  8) Type C-c C-c to send.
;;  # If you are a Japanese, please write in Japanese:-)

;;; History:

;; $Log: viewer.el,v $
;; Revision 1.13  2013/03/14 23:37:05  rubikitch
;; Rename obsolete face name: modeline -> mode-line
;;
;; Revision 1.12  2012/12/31 11:38:16  rubikitch
;; viewer-change-modeline-color: fix advice of select-window
;;
;; Revision 1.11  2012/06/25 10:19:18  rubikitch
;; Bugfix: error when edebug.el is not loaded.
;;
;; Revision 1.10  2012/06/19 15:27:53  rubikitch
;; You can exit view-mode if `edebug-active' is non-nil.
;;
;; Revision 1.9  2012/06/12 01:05:53  rubikitch
;; erase warning
;;
;; Revision 1.8  2012/06/12 01:03:40  rubikitch
;; set viewer-stay-in-unless-writable advice for `view-mode'
;;
;; Revision 1.7  2012/01/16 14:46:49  rubikitch
;; viewer-change-modeline-color-setup: Use window-configuration-change-hook
;;
;; Revision 1.6  2010/10/30 12:13:10  rubikitch
;; viewer-install-extension: call only if view-mode is enabled because (view-mode -1) on emacs24 calls it. mystery.
;;
;; Revision 1.5  2010/05/04 08:56:49  rubikitch
;; Added bug report command
;;
;; Revision 1.4  2009/03/11 08:52:12  rubikitch
;; fix bug in `aggressive-view-mode'
;;
;; Revision 1.3  2009/02/19 02:50:02  rubikitch
;; * view-mode by default
;; * update doc
;;
;; Revision 1.2  2009/02/18 23:57:11  rubikitch
;; * Aggressive view-mode
;; * Stay in view-mode
;; * Change mode-line color
;;
;; Revision 1.1  2009/02/18 15:04:14  rubikitch
;; Initial revision
;;

;;; Code:

(require 'view)
(require 'face-remap)

(defgroup viewer nil
  "Extensions for built-in View mode."
  :group 'view
  :prefix "viewer-")

(defconst viewer-version "1.14"
  "Version of viewer.el.")

;;;; Major-mode-specific View keymaps

(defun viewer--extension-variable (&optional major-mode-symbol)
  "Return the View extension variable for MAJOR-MODE-SYMBOL.
Use the current major mode if MAJOR-MODE-SYMBOL is nil."
  (intern (format "%s-view-mode" (or major-mode-symbol major-mode))))

(defun define-overriding-view-mode-map-internal (major-mode-symbol key-bindings)
  "Install a View-mode keymap for MAJOR-MODE-SYMBOL.
KEY-BINDINGS consists of (KEY . COMMAND) pairs using kbd notation."
  (let* ((map-symbol (intern (format "%s-view-map" major-mode-symbol)))
         (mode-symbol (viewer--extension-variable major-mode-symbol))
         (map (make-sparse-keymap)))
    (dolist (binding key-bindings)
      (define-key map (kbd (car binding)) (cdr binding)))
    (set map-symbol map)
    (unless (boundp mode-symbol)
      (set mode-symbol nil))
    (setq minor-mode-map-alist
          (cons (cons mode-symbol map)
                (assq-delete-all mode-symbol minor-mode-map-alist)))
    (when (and view-mode (eq major-mode major-mode-symbol))
      (viewer-install-extension))
    nil))

(defmacro define-overriding-view-mode-map (major-mode-symbol &rest key-bindings)
  "Define a View-mode keymap for MAJOR-MODE-SYMBOL.
KEY-BINDINGS are (KEY . COMMAND) entries, e.g.

  (define-overriding-view-mode-map emacs-lisp-mode
    ("C-m" . find-function)
    ("C-j" . find-variable))"
  (declare (indent 1))
  (let ((map-symbol (intern (format "%s-view-map" major-mode-symbol)))
        (mode-symbol (viewer--extension-variable major-mode-symbol)))
    (list 'progn
          (list 'defvar map-symbol nil "View keymap for this major mode.")
          (list 'defvar-local mode-symbol nil "View keymap active in this buffer.")
          (list 'define-overriding-view-mode-map-internal
                (list 'quote major-mode-symbol) (list 'quote key-bindings)))))

(defun viewer-install-extension ()
  "Enable a configured major-mode-specific View keymap in this buffer."
  (let ((symbol (viewer--extension-variable)))
    (when (and view-mode (assq symbol minor-mode-map-alist))
      (set (make-local-variable symbol) t))))

(defun viewer-uninstall-extension ()
  "Disable the current major-mode-specific View keymap."
  (let ((symbol (viewer--extension-variable)))
    (when (local-variable-p symbol)
      (kill-local-variable symbol))))

(defun viewer--sync-extension ()
  "Synchronize the major-mode extension with View-mode state."
  (if view-mode
      (viewer-install-extension)
    (viewer-uninstall-extension)))

(add-hook 'view-mode-hook #'viewer--sync-extension)

;;;; View mode by filename

(defcustom view-mode-by-default-regexp nil
  "Regexp matching filenames to enter View mode on visiting.
Nil disables this feature."
  :type '(choice (const :tag "Disabled" nil) regexp)
  :group 'viewer)

(defun view-mode-by-default-setup ()
  "Enable View mode when the filename matches `view-mode-by-default-regexp`."
  (when (and buffer-file-name view-mode-by-default-regexp
             (string-match-p view-mode-by-default-regexp buffer-file-name))
    (view-mode 1)
    (message "view-mode by view-mode-by-default-regexp.")))

;; Retain the original, lightweight, file-visiting hook.
(add-hook 'find-file-hook #'view-mode-by-default-setup)

;;;; Aggressive View mode (optional)

(defcustom viewer-aggressive-minimum-size 100
  "Minimum buffer size to enable aggressive View mode."
  :type 'integer
  :group 'viewer)

(defcustom viewer-aggressive-writable t
  "Non-nil keeps writable files editable in aggressive View mode.
Unwritable files are always read-only."
  :type 'boolean
  :group 'viewer)

(defun aggressive-view-mode ()
  "Enable View mode for sufficiently large regular files."
  (when (and buffer-file-name
             (> (buffer-size) viewer-aggressive-minimum-size)
             (file-regular-p buffer-file-name))
    (view-mode 1)
    (setq buffer-read-only
          (or (not viewer-aggressive-writable)
              (not (file-writable-p buffer-file-name))))))

(defun viewer--aggressive-after-find-file (buffer)
  "Apply aggressive View mode to BUFFER and return BUFFER unchanged."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (aggressive-view-mode)))
  buffer)

(defun viewer-aggressive-setup (arg)
  "Enable or disable aggressive View mode according to ARG.
If ARG is t, use `find-file-hook`.  If ARG is `force`, also
visit already-open buffers using advice on `find-file-noselect`.
If ARG is nil, remove both mechanisms."
  (remove-hook 'find-file-hook #'aggressive-view-mode)
  (advice-remove 'find-file-noselect #'viewer--aggressive-after-find-file)
  (pcase arg
    ('force
     (advice-add 'find-file-noselect :filter-return
                 #'viewer--aggressive-after-find-file))
    ('nil nil)
    (_ (add-hook 'find-file-hook #'aggressive-view-mode))))

;;;; Stay in View mode for unwritable files (optional)

(defvar view-mode-force-exit nil
  "Non-nil permits an explicit exit from View mode.")

(defun viewer--stay-in-unwritable-p ()
  "Return non-nil if leaving View mode should be prevented."
  (and view-mode buffer-file-name
       (not (file-writable-p buffer-file-name))
       (not view-mode-force-exit)
       (not (bound-and-true-p edebug-active))))

(defun viewer--guard-view-mode (original &rest args)
  "Call ORIGINAL with ARGS unless it would disable protected View mode."
  (let ((arg (car args)))
    (if (and (viewer--stay-in-unwritable-p)
             (or (null arg) (eq arg 'toggle)
                 (and (numberp arg) (<= arg 0))))
        (message "File is unwritable, so stay in view-mode.")
      (apply original args))))

(defun viewer--guard-view-mode-exit (original &rest args)
  "Call ORIGINAL with ARGS unless View mode must remain enabled."
  (if (viewer--stay-in-unwritable-p)
      (message "File is unwritable, so stay in view-mode.")
    (apply original args)))

(defun view-mode-force-exit ()
  "Explicitly leave View mode even when the file is unwritable."
  (interactive)
  (let ((view-mode-force-exit t))
    (view-mode-exit)))

(defun viewer-stay-in-setup ()
  "Install protection against exiting View mode on unwritable files.
Setup is idempotent.  This feature remains opt-in."
  (unless (advice-member-p #'viewer--guard-view-mode 'view-mode)
    (advice-add 'view-mode :around #'viewer--guard-view-mode))
  (unless (advice-member-p #'viewer--guard-view-mode-exit 'view-mode-exit)
    (advice-add 'view-mode-exit :around #'viewer--guard-view-mode-exit)))

(defun viewer-stay-in-teardown ()
  "Remove protection installed by `viewer-stay-in-setup`."
  (advice-remove 'view-mode #'viewer--guard-view-mode)
  (advice-remove 'view-mode-exit #'viewer--guard-view-mode-exit))

;;;; Buffer-local mode-line coloring (optional)

(defvar viewer-modeline-color-default (face-background 'mode-line nil t)
  "Original global background, retained for compatibility.
Viewer now uses buffer-local face remapping instead of writing it.")

(defcustom viewer-modeline-color-unwritable "tomato"
  "Active mode-line background in View mode when the file is unwritable."
  :type 'color
  :group 'viewer)

(defcustom viewer-modeline-color-view "orange"
  "Active mode-line background in View mode."
  :type 'color
  :group 'viewer)

(defvar-local viewer--modeline-cookie nil
  "Cookie for viewer's local mode-line face remapping.")

(defvar-local viewer--modeline-color nil
  "Last mode-line background chosen in this buffer.")

(defun viewer--desired-modeline-color ()
  "Return the desired mode-line background color, or nil."
  (when view-mode
    (if (and buffer-file-name
             (not (file-writable-p buffer-file-name)))
        viewer-modeline-color-unwritable
      viewer-modeline-color-view)))

(defun viewer-change-modeline-color ()
  "Update this buffer's active mode-line background.
Use buffer-local remapping of `mode-line-active` (or `mode-line`
on Emacs prior to 29) instead of changing the global face.
Removing the remapping restores the current theme."
  (interactive)
  (let ((color (viewer--desired-modeline-color)))
    (unless (equal color viewer--modeline-color)
      (when viewer--modeline-cookie
        (face-remap-remove-relative viewer--modeline-cookie))
      (setq viewer--modeline-cookie nil
            viewer--modeline-color color)
      (when color
        (setq viewer--modeline-cookie
              (face-remap-add-relative
               (if (facep 'mode-line-active) 'mode-line-active 'mode-line)
               :background color)))
      (force-mode-line-update))))

(defun viewer--on-view-mode ()
  "Enable mode-line updates locally while View mode is active."
  (if view-mode
      (add-hook 'post-command-hook #'viewer-change-modeline-color nil t)
    (remove-hook 'post-command-hook #'viewer-change-modeline-color t))
  (viewer-change-modeline-color))

(defun viewer-change-modeline-color-setup ()
  "Install View-mode mode-line coloring, without affecting other buffers.
This may be called at initialization or from `view-mode-hook`.
Re-running it does not install duplicate hooks."
  (add-hook 'view-mode-hook #'viewer--on-view-mode)
  ;; If called from a running View-mode hook, apply the color immediately.
  (viewer--on-view-mode))

(defun viewer-change-modeline-color-teardown ()
  "Remove View-mode mode-line coloring and restore theme faces."
  (remove-hook 'view-mode-hook #'viewer--on-view-mode)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (remove-hook 'post-command-hook #'viewer-change-modeline-color t)
      (when viewer--modeline-cookie
        (face-remap-remove-relative viewer--modeline-cookie))
      (setq viewer--modeline-cookie nil
            viewer--modeline-color nil)
      (force-mode-line-update))))

;;;; Bug report
(defvar viewer-maintainer-mail-address
  (concat "rubiki" "tch@ru" "by-lang.org"))
(defvar viewer-bug-report-salutation
  "Describe bug below, using a precise recipe.

When I executed M-x ...

How to send a bug report:
  1) Be sure to use the LATEST version of viewer.el.
  2) Enable debugger. M-x toggle-debug-on-error or (setq debug-on-error t)
  3) Use Lisp version instead of compiled one: (load \"viewer.el\")
  4) If you got an error, please paste *Backtrace* buffer.
  5) Type C-c C-c to send.
# If you are a Japanese, please write in Japanese:-)")
(defun viewer-send-bug-report ()
  (interactive)
  (require 'reporter)
  (reporter-submit-bug-report
   viewer-maintainer-mail-address
   "viewer.el"
   (apropos-internal "^view" 'boundp)
   nil nil
   viewer-bug-report-salutation))

(provide 'viewer)

;; How to save (DO NOT REMOVE!!)
;; (emacswiki-post "viewer.el")
;;; viewer.el ends here
