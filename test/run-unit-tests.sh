#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
elpa_dir=${PRELUDE_ELPA_DIR:-elpa}
evil_dir=$(find "$elpa_dir" -maxdepth 1 -type d -name 'evil-*' -print -quit)
eat_dir=$(find "$elpa_dir" -maxdepth 1 -type d -name 'eat-*' -print -quit)
test -f "$evil_dir/evil.el"
test -f "$eat_dir/eat.el"

emacs --batch -Q -L "$evil_dir" -L personal \
  -l test/my-utils-test.el \
  -l test/my-vendor-test.el \
  -f ert-run-tests-batch-and-exit

PRELUDE_EVIL_DIR="$evil_dir" PRELUDE_EAT_DIR="$eat_dir" \
  emacs --batch -Q \
    -l test/my-eat-test-bootstrap.el \
    -l test/my-eat-test.el \
    -f ert-run-tests-batch-and-exit
