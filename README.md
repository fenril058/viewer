# viewer.el

Viewer extends **Emacs's built-in View mode** with optional features.
Originally written by rubikitch. This fork keeps the original setup API
and the original behavior while updating old implementation details.

Requires Emacs 27.1 or newer.

## Features

- Automatically use View mode for filenames matching a configurable regexp,
  without changing the selected major mode.
- Optionally guard against accidentally leaving View mode on unwritable files.
- Optionally highlight the active mode line of View-mode buffers.
- Optionally use View mode aggressively for large files.
- Optionally define major-mode-specific keymaps in View mode.

No additional global minor mode is introduced. Each optional setup remains
independent.

## Existing setup.el configuration

The original configuration continues to work:

~~~elisp
(setup (:package viewer)
  (:key-chord "kj" #'view-mode)
  (:with-mode view-mode
    (:bind
     "h" backward-char
     "j" next-line
     "k" previous-line
     "l" forward-char
     "J" View-scroll-line-forward
     "K" View-scroll-line-backward
     "q" kill-buffer))
  (setopt view-read-only t
          viewer-modeline-color-unwritable "tomato"
          viewer-modeline-color-view "orange"
          view-mode-by-default-regexp "\\.log$")
  (:with-hook view-mode-hook
    (:hook viewer-change-modeline-color-setup))
  (:with-hook read-only-mode-hook
    (:hook viewer-stay-in-setup)))
~~~

Alternatively, if the package is already loaded during initialization,
the setup functions may be called once directly:

~~~elisp
(require 'viewer)
(viewer-change-modeline-color-setup)
(viewer-stay-in-setup)
~~~

The View-mode coloring setup is idempotent, even if called from
`view-mode-hook` as in the original configuration.

### Mode-line coloring

On Emacs 29+ the active window uses the `mode-line-active` face,
which can override the `mode-line` face's background. The old Viewer
implementation changed the global `mode-line` background and could
therefore fail to show the requested color on newer Emacs.

Viewer now uses `face-remap-add-relative` on the **active mode line of
each buffer**. Inactive windows and unrelated buffers are not changed,
and leaving View mode restores the current theme. The original
`viewer-modeline-color-view` and
`viewer-modeline-color-unwritable` customizations still work.

While View mode is active, coloring is refreshed through a *buffer-local*
post-command hook, including when a file becomes unwritable externally.
No global per-command color hook is installed. You can disable coloring
with:

~~~elisp
(viewer-change-modeline-color-teardown)
~~~

### Unwritable-file protection

Call `viewer-stay-in-setup` to retain View mode on unwritable files.
The command `view-mode-force-exit` still allows explicitly leaving it.

Remove that protection with:

~~~elisp
(viewer-stay-in-teardown)
~~~

### Automatic files and aggressive mode

The filename regexp feature retains the original small
`find-file-hook`, because it must preserve the selected major mode.
`auto-mode-alist` is for major-mode selection and is not an equivalent
replacement for enabling the View minor mode.

Aggressive View mode stays opt-in:

~~~elisp
(viewer-aggressive-setup t)
(viewer-aggressive-setup 'force)
(viewer-aggressive-setup nil)
~~~

### Major-mode-specific View keys

~~~elisp
(define-overriding-view-mode-map emacs-lisp-mode
  ("C-m" . find-function)
  ("C-j" . find-variable))
~~~

## Tests

~~~shell
emacs -Q --batch -L . -f batch-byte-compile viewer.el
emacs -Q --batch -L . -l test/viewer-test.el -f ert-run-tests-batch-and-exit
~~~

The GitHub Actions workflow runs the tests on Emacs 27.2, 29.4 and 31.1.
