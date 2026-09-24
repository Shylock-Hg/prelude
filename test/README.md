# vterm extended-command cursor regression test

The primary regression uses a live vterm PTY and checks an ordinary cursor in
Evil normal and insert states without an active selection. A separate test keeps
the visual-selection case covered. The implementation itself does not depend on
Evil. The test needs GNU Emacs with module support, Evil, a built vterm native
module, and `sh` plus `base64` on `PATH`. Install Evil and build vterm using the
vterm project's installation instructions. No dependencies are vendored here.

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

The bootstrap loads the personal configuration with package installation and
server startup stubbed. The tests enable `evil-mode` and leave Evil's visual
pre/post command hooks active. The bootstrap also initializes Evil 1.15's
unbound `evil-mode-buffers` sentinel to nil so normal post-command hooks work in
batch mode.

Verified with GNU Emacs 31.1, Evil 1.15.0, and vterm source revision
`6d715a93fa0e5182bc137d4db09f376e06938aa5`; the environment paths above let you
select other installed or built versions.
