# Terminal emulator regression tests

The active terminal configuration uses Eat (`personal/my-eat.el`). The older
vterm configuration (`personal/my-vterm.el`) is kept but no longer loaded
(issue #10), and its regression suite is retained so it can be re-enabled.

## Eat

The tests cover the Eat configuration in `personal/my-eat.el`: the toggle and
multi-session commands exist and are wired to the expected keys, the toggle key
is reserved for Emacs inside Eat, Evil's normal/insert states receive the
bindings, and a real PTY survives toggling, opening several sessions and running
a shell command.

The suite needs GNU Emacs with Evil and Eat sources, plus `sh` on `PATH`. No
dependencies are vendored here.

From the repository root, set the package directories (each directory must
contain `eat.el` or `evil.el`) and run:

```sh
PRELUDE_EVIL_DIR=/path/to/evil \
PRELUDE_EAT_DIR=/path/to/emacs-eat \
emacs --batch -Q \
  -l test/my-eat-test-bootstrap.el \
  -l test/my-eat-test.el \
  -f ert-run-tests-batch-and-exit
```

The bootstrap loads the personal configuration with package installation and
server startup stubbed. Verified with GNU Emacs 31.1, Evil 1.15.0 and Eat
0.9.4.

## vterm (disabled)

The vterm suite still exercises the extended-command cursor handling in
`personal/my-vterm.el`. It needs GNU Emacs with module support, Evil, a built
vterm native module, and `sh` plus `base64` on `PATH`.

From the repository root, set the package directories (each directory must
contain `evil.el` or `vterm.el`) and run:

```sh
PRELUDE_EVIL_DIR=/path/to/evil \
PRELUDE_VTERM_DIR=/path/to/emacs-libvterm \
emacs --batch -Q \
  -l test/my-vterm-test-bootstrap.el \
  -l test/my-vterm-test.el \
  -f ert-run-tests-batch-and-exit
```

The suite also enables `evil-mode` and verifies live-PTY cursor behavior;
the implementation itself does not depend on Evil. Verified with GNU Emacs
31.1, Evil 1.15.0 and vterm source revision
`6d715a93fa0e5182bc137d4db09f376e06938aa5`.
