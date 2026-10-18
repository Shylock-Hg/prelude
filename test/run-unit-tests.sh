#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
# Fetch exact commits once; keep dependency sources outside the checkout.
deps_dir=${PRELUDE_TEST_DEPS_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/prelude/test-dependencies}
mkdir -p "$deps_dir"
deps_dir=$(cd "$deps_dir" && pwd)
while read -r name source revision; do
  destination="$deps_dir/$name/$revision"
  if [ ! -d "$destination/.git" ]; then
    mkdir -p "$deps_dir/$name"
    stage=$(mktemp -d "$deps_dir/$name/.fetch-XXXXXX")
    trap 'rm -rf "$stage"' EXIT HUP INT TERM
    git init -q "$stage"
    git -C "$stage" fetch --quiet --depth=1 "$source" "$revision"
    git -C "$stage" checkout --quiet --detach FETCH_HEAD
    test "$(git -C "$stage" rev-parse HEAD)" = "$revision"
    mv "$stage" "$destination"
    trap - EXIT HUP INT TERM
  fi
  test "$(git -C "$destination" rev-parse HEAD)" = "$revision"
done < test/dependencies.txt

dependency_path() {
  revision=$(awk -v name="$1" '$1 == name {print $3}' test/dependencies.txt)
  printf '%s/%s/%s\n' "$deps_dir" "$1" "$revision"
}
evil_dir=${PRELUDE_EVIL_DIR:-$(dependency_path evil)}
eat_dir=${PRELUDE_EAT_DIR:-$(dependency_path eat)}
goto_chg_dir=$(dependency_path goto-chg)

emacs --batch -Q -L "$evil_dir" -L "$goto_chg_dir" -L personal \
  -l test/my-utils-test.el \
  -l test/my-vendor-test.el \
  -f ert-run-tests-batch-and-exit

PRELUDE_EVIL_DIR="$evil_dir" PRELUDE_EAT_DIR="$eat_dir" \
PRELUDE_GOTO_CHG_DIR="$goto_chg_dir" \
  emacs --batch -Q \
    -l test/my-eat-test-bootstrap.el \
    -l test/my-eat-test.el \
    -f ert-run-tests-batch-and-exit

emacs --batch -Q -L personal -L "$(dependency_path gt)" -L "$(dependency_path pdd)" \
  -l test/my-translate-test.el \
  -f ert-run-tests-batch-and-exit
