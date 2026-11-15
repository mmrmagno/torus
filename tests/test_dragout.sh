#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

out=$(node --test "$REPO/tests/components/fileuri.test.mjs" 2>&1) || { printf '%s\n' "$out" | grep -E "^not ok|expected|actual" >&2; fail "file uris for drag out"; }
for f in components/CaptureTile.qml island/DynamicIsland.qml; do
  grep -q 'FileDrag {' "$REPO/home/.config/quickshell/torus/$f" || fail "$f offers its file as a drag"
done
echo "dragout: ok"
