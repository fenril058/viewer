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

;; Add optional color, exit protection, and major-mode-specific keys to
;; Emacs's built-in View mode.  Viewer never decides which files should be
;; visited in View mode: file-selection policies belong in the user's init.el.
;;
;; The combined setup is an autoloadable entry point, so users can defer
;; loading the package until View mode is first entered:
;;
;;   (add-hook 'view-mode-hook #'viewer-setup)
;;
;; Package-generated autoloads, or an explicit (autoload 'viewer-setup "viewer"),
;; are needed for the hook function to load this file on demand.  Call the
;; individual *-setup functions instead to select only some enhancements.

;;; Code:

(require 'view)
(require 'face-remap)

(defgroup viewer nil
  "Extensions for built-in View mode."
  :group 'view
  :prefix "viewer-")

(defconst viewer-version "1.15"
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
KEY-BINDINGS are (KEY . COMMAND) pairs in kbd notation."
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

;;;; One-time opt-in setup

;;;###autoload
(defun viewer-setup ()
  "Install Viewer enhancements for built-in View mode.
Use this function as an entry in `view-mode-hook` to load Viewer
on demand (when package autoloads are available).  The initial
View-mode buffer is updated immediately, while future transitions
use the installed hooks.  Calling this function repeatedly is safe.

For selective use, call `viewer-change-modeline-color-setup` and
`viewer-stay-in-setup` individually instead."
  ;; Avoid invoking this one-time initializer on every View-mode toggle.
  (remove-hook 'view-mode-hook #'viewer-setup)
  ;; On first autoload, viewer--sync-extension was added to the hook while
  ;; the hook was already running, so update the current buffer explicitly.
  (viewer--sync-extension)
  (viewer-change-modeline-color-setup)
  (viewer-stay-in-setup))

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
