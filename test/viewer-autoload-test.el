;;; viewer-autoload-test.el --- Cold-load regression -*- lexical-binding: t; -*-

(require 'ert)
(require 'view)

(ert-deftest viewer-test-loads-only-on-first-view-mode ()
  "The hook autoload loads Viewer on demand and initializes the first buffer."
  (should-not (featurep 'viewer))
  (autoload 'viewer-setup "viewer")
  (add-hook 'view-mode-hook #'viewer-setup)
  (unwind-protect
      (with-temp-buffer
        (should-not (featurep 'viewer))
        (should-not view-mode)
        (view-mode 1)
        (should (featurep 'viewer))
        (should viewer--modeline-cookie)
        (should (equal viewer--modeline-color
                       viewer-modeline-color-view))
        (should (advice-member-p #'viewer--guard-view-mode 'view-mode))
        (should-not (memq #'viewer-setup view-mode-hook))
        (view-mode -1)
        (should-not viewer--modeline-cookie))
    (remove-hook 'view-mode-hook #'viewer-setup)
    (when (featurep 'viewer)
      (viewer-change-modeline-color-teardown)
      (viewer-stay-in-teardown))))

(provide 'viewer-autoload-test)
;;; viewer-autoload-test.el ends here
