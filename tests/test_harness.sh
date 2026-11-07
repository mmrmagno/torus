#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

assert_eq a a "equal strings"
assert_fails false
if ( assert_fails true ) 2>/dev/null; then
  echo "assert_fails accepted a passing command" >&2
  exit 1
fi
