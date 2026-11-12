#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
g() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }
git init -q -b main "$F/up"
g "$F/up" commit -q --allow-empty -m "feat: one"
git clone -q "$F/up" "$F/down"
U=$REPO/home/.local/bin/torus-updates
assert_eq "installed" "$(TORUS_REPO=$F/down "$U" torus | cut -f1)" "nothing new: only the installed commit"
g "$F/up" commit -q --allow-empty -m "fix: two"
g "$F/up" commit -q --allow-empty -m "feat: three"
out=$(TORUS_REPO=$F/down TORUS_FETCH_TTL=0 "$U" torus)
assert_eq "installed feat: one|new feat: three|new fix: two" "$(cut -f1,3 <<< "$out" | tr '\t' ' ' | paste -sd'|')" "upstream commits after the installed one, newest first"
assert_eq "" "$(TORUS_REPO=$F/up "$U" torus)" "a checkout without upstream prints nothing"
echo "changelog: ok"
