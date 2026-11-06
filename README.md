# viewer.el

Viewer extends Emacs's **built-in View mode**. It does not decide which
files to open read-only or when to enable View mode.

Originally written by rubikitch. This fork keeps the View-mode
enhancements and Emacs 31 mode-line fix. Requires Emacs 27.1 or newer.

## Scope

Viewer provides:

- Buffer-local active mode-line colors for View mode (orange; tomato for
  non-writable files).
- Optional protection against accidentally leaving View mode in
  non-writable files, plus `view-mode-force-exit`.
- Major-mode-specific key bindings while View mode is active.

Viewer **does not** inspect filenames or file sizes to decide when to
enable View mode. As a consequence, it installs no `find-file-hook` and
no `find-file-noselect` advice.

The existing color and protection setup functions are kept for people
who want to configure those features independently.

## Lazy configuration

A single hook entry is enough when your package manager has installed
Viewer's generated autoloads (the `;;;###autoload` cookie is attached
to `viewer-setup`):

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
  (add-hook 'view-mode-hook #'viewer-setup))
~~~

If your installation does **not** generate/load autoloads, register
this manually before the hook:

~~~elisp
(autoload 'viewer-setup "viewer")
(add-hook 'view-mode-hook #'viewer-setup)
~~~

Viewer is not loaded at startup. On the first View-mode transition,
`viewer-setup` loads Viewer, installs color/protection hooks and advice
**once**, and immediately updates the current buffer. Subsequent
View-mode toggles only run the normal lifecycle hooks.

There is no user-defined initializer and no global Viewer minor mode.

### Selective setup

If you want only certain features rather than the combined
`viewer-setup`, load Viewer explicitly and call only the needed
setup functions **once**:

~~~elisp
(require 'viewer)
(viewer-change-modeline-color-setup)
;; Optional:
(viewer-stay-in-setup)
~~~

Color setup and unwritable-file protection remain independently
reversible via `viewer-change-modeline-color-teardown` and
`viewer-stay-in-teardown`.

### Opening .log files read-only (your init.el, not Viewer)

For example:

~~~elisp
(setopt view-read-only t)
(add-hook 'find-file-hook
          (lambda ()
            (when (and buffer-file-name
                       (string-match-p "\\.log\\'" buffer-file-name))
              (read-only-mode 1))))
~~~

This is a **user policy**, not a Viewer feature.
Emacs's standard `view-read-only` integration enters built-in View mode
when `read-only-mode` enables read-only status. That transition calls
`view-mode-hook` and can autoload Viewer using the setup above.

Read-only buffers and files that are not writable on disk are not the
same thing. A writable `.log` deliberately opened read-only will have
the **orange** View mode line, not the tomato unwritable-file line.
The unwritable-file exit protection likewise checks file permissions.

## Mode-line colors

Emacs 29+ can use `mode-line-active` for the selected window, so the
old global `mode-line` background change did not reliably display
Viewer's color on Emacs 31. Viewer now uses buffer-local
`face-remap-add-relative`, and restores theme colors on exit.
Colors can be customized via `viewer-modeline-color-view` and
`viewer-modeline-color-unwritable`.

Color refresh uses a buffer-local `post-command-hook` only while View
mode is active, including permission changes that happen externally.

## Breaking changes

Filename- and size-based View activation are removed from Viewer:

- `view-mode-by-default-regexp` and `view-mode-by-default-setup`
- `viewer-aggressive-setup` and `aggressive-view-mode`
- `viewer-aggressive-minimum-size` and `viewer-aggressive-writable`

A package-level `find-file-hook` and `find-file-noselect` advice are
no longer installed. Put file-selection/read-only rules in init.el or
a dedicated package instead.

## Tests

~~~shell
emacs -Q --batch -L . -f batch-byte-compile viewer.el
emacs -Q --batch -L . -l test/viewer-test.el -f ert-run-tests-batch-and-exit
emacs -Q --batch -L . -l test/viewer-autoload-test.el -f ert-run-tests-batch-and-exit
~~~

GitHub Actions runs these against Emacs 27.2, 29.4, and 31.1.
