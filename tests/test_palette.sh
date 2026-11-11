#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

out=$(node --test "$REPO/tests/palette/route.test.mjs" 2>&1) || { printf '%s\n' "$out" | grep -E "^not ok|error|expected|actual" >&2; fail "palette routing"; }
grep -q '^# fail 0$' <<< "$out" || fail "palette routing: $out"
