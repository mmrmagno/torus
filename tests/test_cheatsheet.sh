#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

out=$(node --test "$REPO/tests/cheatsheet/keys.test.mjs" 2>&1) || { printf '%s\n' "$out" | grep -E "^not ok|error|expected|actual" >&2; fail "cheat sheet keys"; }
grep -q '^# fail 0$' <<< "$out" || fail "cheat sheet keys: $out"
grep -q 'select accent color\|select animations' "$REPO/home/.config/hypr/torus/binds.lua" && fail "theme binds still say select accent color or animations"
echo "cheatsheet: ok"
