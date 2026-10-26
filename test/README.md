# Personal configuration regression tests

Run the complete unit suite from a clean checkout:

```sh
test/run-unit-tests.sh
```

The runner fetches the exact commits in [the dependency manifest](dependencies.txt)
on its first run. Sources are cached under
`${XDG_CACHE_HOME:-$HOME/.cache}/prelude/test-dependencies`; set
`PRELUDE_TEST_DEPS_DIR` to override this location. Later runs reuse the cache
without fetching. No Prelude startup or ELPA installation is needed.
GNU Emacs, Git, `sh`, `tic`, `infocmp`, and `clear` must be installed.
The graphical reader smoke still requires MuPDF and a graphical Emacs.

The active terminal configuration uses Eat (`personal/my-eat.el`). The older
vterm configuration (`personal/my-vterm.el`) is kept but no longer loaded
(issue #10), and its regression suite is retained so it can be re-enabled.

## Personal utilities and vendor cloning

The utility tests cover selected-file handling in `personal/my-utils.el`, and
the vendor tests cover clone staging and cleanup in `personal/my-vendor.el`.
They run offline: Git is stubbed in the vendor tests, and Evil is optional. The
two Evil integration tests in the utility suite are reported as skipped when
Evil is unavailable.

From the repository root, run:

```sh
emacs --batch -Q -L personal \
  -l test/my-utils-test.el \
  -l test/my-vendor-test.el \
  -f ert-run-tests-batch-and-exit
```

## Eat

The tests cover the Eat configuration in `personal/my-eat.el`: the toggle and
multi-session commands exist and are wired to the expected keys, `C-t` opens
Eat from ordinary buffers in Evil's normal state, and the toggle takes
precedence over a minor mode's normal-state binding. The toggle key is reserved
for Emacs inside Eat, and a real PTY survives toggling, opening several
sessions and running a shell command. The terminfo test checks that `clear`
emits the scrollback erase sequence and that a missing compiled entry is rebuilt.

Evil `i`, `a`, `A`, `x`, `X`, counted deletion and change operators are
checked against a live Bash command, including its executed result. Regression
coverage includes insert-then-delete and delete-then-insert macros without
output waits, Backspace-then-type and Left-then-type macros, typing across the
right terminal edge, primary and continuation prompt protection, insertion
before wide characters, deletion of and across wide characters, prompt-
crossing ranges, and the yank and small-delete registers.

Direct terminal edits require Eat shell integration to identify the input
boundary. For Bash, add this to `.bashrc` (Eat sets the directory variable):

```sh
[ -n "$EAT_SHELL_INTEGRATION_DIR" ] && . "$EAT_SHELL_INTEGRATION_DIR/bash"
```

Edits support characterwise ranges after the known prompt on the terminal
cursor's buffer line. Prompt text, unknown input boundaries, scrollback and
linewise deletions report a user error. Returning to Insert state from
scrollback resumes at the live terminal cursor. Shell input drains queued
output until it is idle for at least 33 milliseconds (or Eat's configured
maximum latency), with a one-second cap during continuous output. This uses
the actual terminal response, allowing completion, history, kill/yank and
wrapped typing without predicting their contents. Explicit Evil cursor
movement and deletion wait up to one second for the shell's display to confirm
them; a timeout invalidates the input boundary until the next integrated
prompt. Eat line mode retains ordinary Emacs/Evil editing.

The suite needs GNU Emacs with Evil and Eat sources, plus `bash`, `sh`, `tic`,
`infocmp`, and `clear` on `PATH`. The runner fetches pinned sources into its
dependency cache.

From the repository root, set the package directories (each directory must
contain `eat.el`, `evil.el`, or `goto-chg.el`) and run:

```sh
PRELUDE_EVIL_DIR=/path/to/evil \
PRELUDE_EAT_DIR=/path/to/emacs-eat \
PRELUDE_GOTO_CHG_DIR=/path/to/goto-chg \
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

## Translation

`personal/my-translate.el` installs the MELPA package `gt` at startup. Select
text, then run `M-x my/translate-en2zh-selected` or
`M-x my/translate-zh2en-selected`. Both commands also accept the last Evil
visual selection when invoked through the extended-command minibuffer.
Results appear in a separate gt buffer; the source buffer stays intact.
Translation uses Google Translate and requires network access, with no API key.
Missing or whitespace-only selections produce a user error.

The regression tests use real gt taker, engine and render objects, but intercept
`gt-start` before network requests. They check both directions, region and Evil
marker selections, preservation of selected text, and invalid selections.
`test/run-unit-tests.sh` runs them using the pinned gt and pdd sources.
For a standalone run with gt and its pdd dependency on the load path:

```sh
emacs --batch -Q -L /path/to/gt.el -L /path/to/pdd.el -L personal \
  -l test/my-translate-test.el -f ert-run-tests-batch-and-exit
```

## Reader pin

`my-reader-revision` in `personal/my-reader.el` pins the exact upstream commit.
The GUI smoke asserts that same commit. To upgrade, change the pin and run
`.github/scripts/reader-gui-smoke.el` with graphical Emacs and MuPDF installed.
Existing reader checkouts at another revision produce an actionable error;
move `vendor/divyaranjan/emacs-reader` aside and restart to clone and build the
pin. Existing checkouts are preserved rather than reset over local changes.
