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

## Configuration

The `viewer-change-modeline-color-setup` and `viewer-stay-in-setup`
functions **install** hooks/advice; they are not event handlers.
Call each once after loading `viewer.el`. In particular, enabling
`view-mode` does not necessarily run `read-only-mode-hook`.

### Minimal initialization (when eager loading is acceptable)

~~~elisp
(require 'viewer)
(setopt view-read-only t
        view-mode-by-default-regexp "\\.log\\'"
        viewer-modeline-color-view "orange"
        viewer-modeline-color-unwritable "tomato")
(viewer-change-modeline-color-setup)
(viewer-stay-in-setup)
~~~

The existing `setup.el` configuration that places these two
`*-setup` functions on `view-mode-hook` and
`read-only-mode-hook` is still tolerated, but should **not** be used
as the recommended setup. Repeated installation is unnecessary,
and the read-only hook might never run for an explicitly entered
View-mode buffer.

### Lazy loading with setup.el

The following example does **not** load viewer.el at startup.
It initializes Viewer once on the first transition into View mode,
whether explicit or via Emacs's own `view-read-only` handling.
The small file hook ensures even the **first** `.log` file enters
View mode, without loading viewer.el for unrelated files.

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
  (setopt view-read-only t)

  (defun my/viewer-initialize-once ()
    (when view-mode
      (remove-hook 'view-mode-hook #'my/viewer-initialize-once)
      (require 'viewer)
      (setopt viewer-modeline-color-unwritable "tomato"
              viewer-modeline-color-view "orange")
      (viewer-change-modeline-color-setup)
      (viewer-stay-in-setup)))
  (add-hook 'view-mode-hook #'my/viewer-initialize-once)

  ;; A first .log file should trigger View mode, even before Viewer is loaded.
  (add-hook 'find-file-hook
            (lambda ()
              (when (and buffer-file-name
                         (string-match-p "\\.log\\'" buffer-file-name))
                (view-mode 1)))))
~~~

This initial `find-file-hook` is intentionally tiny: it only
selects the built-in minor View mode. The more general
`view-mode-by-default-regexp` facility provided by viewer.el
remains available when the package is loaded eagerly. Using
that facility to process the **first** `.log` file necessarily
requires Viewer to have been loaded already; lazy loading and
first-file activation therefore need a small bootstrap hook.

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
