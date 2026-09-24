# Eat terminal regression tests

The tests cover the Eat terminal configuration in `personal/my-eat.el`: the
toggle and multi-session commands exist and are wired to the expected keys, the
toggle key is reserved for Emacs inside Eat, Evil's normal/insert states receive
the bindings, and a real PTY survives toggling, opening several sessions and
running a shell command.

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
