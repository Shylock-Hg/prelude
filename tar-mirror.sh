#! /usr/bin/env bash

readonly SCRIPT_DIR=$(dirname $0)

pushd ~/.elpa-mirror/
readonly DATE=$(git log -1 --format=%cd --date=short)
popd

tar --zst -cf ~/Data/elpa-mirror-$(cat ${SCRIPT_DIR}/.emacsversion)_${DATE}.tar.zst -C "$HOME" .elpa-mirror
