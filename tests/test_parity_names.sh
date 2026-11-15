#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

P=$REPO/vm/parity.sh
dup=$(grep -o '^check_[a-z0-9_]*()' "$P" | sort | uniq -d | tr '\n' ' ')
[[ -z $dup ]] || fail "a later parity section silently replaces an earlier one: $dup"
dup=$(grep -oE '^  [a-z0-9]+\) check_' "$P" | sort | uniq -d | tr '\n' ' ')
[[ -z $dup ]] || fail "a section name is listed twice: $dup"
for f in $(grep -o '^check_[a-z0-9_]*()' "$P" | tr -d '()'); do
  grep -qE "^  [a-z0-9]+\) $f ;;" "$P" || fail "$f cannot be run on its own"
done
echo "parity names: ok"
