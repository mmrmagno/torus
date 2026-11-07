#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
rc=0
for t in test_*.sh; do
  if out=$(bash "$t" 2>&1); then
    echo "PASS $t"
  else
    echo "FAIL $t"
    printf '%s\n' "$out" | tail -20 | sed 's/^/  /'
    rc=1
  fi
done
exit $rc
