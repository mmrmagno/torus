#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$REPO"
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || { echo "skip: no git here"; exit 0; }
extra=$(git ls-files '*.md' | grep -vx 'README.md' || true)
[[ -z $extra ]] || fail "README.md is the only document in this repo: $extra"
echo "docs: ok"
