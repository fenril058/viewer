;;; viewer-test.el --- ERT tests for viewer.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'viewer)

(defun viewer-test--mode-line-face ()
  "Return the active mode-line face used on this Emacs version."
  (if (facep 'mode-line-active) 'mode-line-active 'mode-line))

(ert-deftest viewer-test-original-setup-from-view-mode-hook ()
  "An existing setup.el configuration colors the first View-mode entry."
  (unwind-protect
      (progn
        (add-hook 'view-mode-hook #'viewer-change-modeline-color-setup)
        (with-temp-buffer
          (should-not view-mode)
          (view-mode 1)
          (should (equal viewer--modeline-color viewer-modeline-color-view))
          (should viewer--modeline-cookie)
          (view-mode -1)
          (should-not viewer--modeline-cookie)
          (should-not viewer--modeline-color)))
    (remove-hook 'view-mode-hook #'viewer-change-modeline-color-setup)
    (viewer-change-modeline-color-teardown)))

(ert-deftest viewer-test-colors-are-buffer-local ()
  "View mode only remaps the active mode line of that buffer."
  (let ((original (face-background 'mode-line nil t))
        (other (generate-new-buffer " *viewer-other*")))
    (unwind-protect
        (progn
          (viewer-change-modeline-color-setup)
          (with-temp-buffer
            (view-mode 1)
            (should (assq (viewer-test--mode-line-face)
                          face-remapping-alist))
            (should (equal viewer--modeline-color viewer-modeline-color-view))
            (with-current-buffer other
              (should-not viewer--modeline-cookie)
              (should-not (assq (viewer-test--mode-line-face)
                                face-remapping-alist)))
            (should (equal original (face-background 'mode-line nil t)))
            (view-mode -1)
            (should-not (assq (viewer-test--mode-line-face)
                              face-remapping-alist))))
      (viewer-change-modeline-color-teardown)
      (kill-buffer other))))

(ert-deftest viewer-test-unwritable-colors ()
  "File writability selects tomato over orange, and refresh does not leak."
  (let ((writable t))
    (unwind-protect
        (progn
          (viewer-change-modeline-color-setup)
          (with-temp-buffer
            (setq-local buffer-file-name "/tmp/viewer-color-test.log")
            (cl-letf (((symbol-function 'file-writable-p)
                       (lambda (_file) writable)))
              (view-mode 1)
              (should (equal viewer--modeline-color viewer-modeline-color-view))
              (setq writable nil)
              (viewer-change-modeline-color)
              (should (equal viewer--modeline-color viewer-modeline-color-unwritable))
              (should viewer--modeline-cookie)
              (setq writable t)
              (viewer-change-modeline-color)
              (should (equal viewer--modeline-color viewer-modeline-color-view))
              (view-mode -1)
              (should-not viewer--modeline-cookie))))
      (viewer-change-modeline-color-teardown))))

(ert-deftest viewer-test-opt-in-setup-and-teardown ()
  "Color update hooks only exist after explicitly invoking setup."
  (unwind-protect
      (progn
        (viewer-change-modeline-color-teardown)
        (should-not (memq #'viewer--on-view-mode view-mode-hook))
        (viewer-change-modeline-color-setup)
        (viewer-change-modeline-color-setup)
        (should (memq #'viewer--on-view-mode view-mode-hook))
        (with-temp-buffer
          (view-mode 1)
          (should (memq #'viewer-change-modeline-color post-command-hook))
          (viewer-change-modeline-color-teardown)
          (should-not (memq #'viewer-change-modeline-color post-command-hook))
          (should-not viewer--modeline-cookie)))
    (viewer-change-modeline-color-teardown)))

(ert-deftest viewer-test-default-regexp ()
  "The existing filename regexp feature should preserve major mode."
  (let ((view-mode-by-default-regexp "\\.log\\'"))
    (with-temp-buffer
      (emacs-lisp-mode)
      (setq-local buffer-file-name "/tmp/viewer.log")
      (view-mode-by-default-setup)
      (should view-mode)
      (should (eq major-mode 'emacs-lisp-mode)))
    (with-temp-buffer
      (setq-local buffer-file-name "/tmp/viewer.txt")
      (view-mode-by-default-setup)
      (should-not view-mode))))

(ert-deftest viewer-test-opt-in-stay-in-and-force-exit ()
  "Writability protection is opt-in, and an explicit force exit works."
  (unwind-protect
      (progn
        (viewer-stay-in-setup)
        (viewer-stay-in-setup)
        (with-temp-buffer
          (setq-local buffer-file-name "/tmp/viewer-unwritable.log")
          (cl-letf (((symbol-function 'file-writable-p)
                     (lambda (_file) nil)))
            (view-mode 1)
            (view-mode -1)
            (should view-mode)
            (view-mode 'toggle)
            (should view-mode)
            (view-mode-exit t)
            (should view-mode)
            (let ((view-mode-force-exit t))
              (view-mode -1))
            (should-not view-mode))))
    (viewer-stay-in-teardown)))

(ert-deftest viewer-test-protection-does-not-block-enable ()
  "Entering View mode is always allowed for an unwritable file."
  (unwind-protect
      (progn
        (viewer-stay-in-setup)
        (with-temp-buffer
          (setq-local buffer-file-name "/tmp/viewer-unwritable.log")
          (cl-letf (((symbol-function 'file-writable-p)
                     (lambda (_file) nil)))
            (view-mode 1)
            (should view-mode))))
    (viewer-stay-in-teardown)))

(ert-deftest viewer-test-optional-aggressive-setup ()
  "The original t, force, and nil setup modes remain supported."
  (unwind-protect
      (progn
        (viewer-aggressive-setup 'force)
        (viewer-aggressive-setup 'force)
        (should (advice-member-p #'viewer--aggressive-after-find-file
                                 'find-file-noselect))
        (viewer-aggressive-setup t)
        (should (memq #'aggressive-view-mode find-file-hook))
        (should-not (advice-member-p #'viewer--aggressive-after-find-file
                                     'find-file-noselect))
        (viewer-aggressive-setup nil)
        (should-not (memq #'aggressive-view-mode find-file-hook)))
    (viewer-aggressive-setup nil)))

(ert-deftest viewer-test-aggressive-file-writability ()
  "Aggressive view preserves the usual writable-file behavior."
  (let ((file (make-temp-file "viewer-test-")))
    (unwind-protect
        (with-temp-buffer
          (insert (make-string 150 ?a))
          (setq-local buffer-file-name file)
          (let ((viewer-aggressive-minimum-size 100)
                (viewer-aggressive-writable t))
            (aggressive-view-mode)
            (should view-mode)
            (should-not buffer-read-only))
          (view-mode -1)
          (let ((viewer-aggressive-minimum-size 100)
                (viewer-aggressive-writable nil))
            (aggressive-view-mode)
            (should view-mode)
            (should buffer-read-only)))
      (delete-file file))))

(ert-deftest viewer-test-overriding-keymap ()
  "Major-mode-specific View bindings remain opt-in and buffer-local."
  (define-overriding-view-mode-map emacs-lisp-mode
    ("C-c v" . ignore))
  (with-temp-buffer
    (emacs-lisp-mode)
    (view-mode 1)
    (should (bound-and-true-p emacs-lisp-mode-view-mode))
    (should (eq (lookup-key emacs-lisp-mode-view-map (kbd "C-c v")) 'ignore))
    (view-mode -1)
    (should-not (local-variable-p 'emacs-lisp-mode-view-mode))))

(provide 'viewer-test)
;;; viewer-test.el ends here
