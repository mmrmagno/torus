#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
g() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }
git init -q -b main "$F/up"
g "$F/up" commit -q --allow-empty -m "feat: one"
git clone -q "$F/up" "$F/down"
mkdir -p "$F/down/home/.local/bin" "$F/up/home/.local/bin"
cp "$REPO/home/.local/bin/torus-update" "$REPO/home/.local/bin/torus-updates" "$F/down/home/.local/bin/"
cp "$REPO/home/.local/bin/torus-update" "$REPO/home/.local/bin/torus-updates" "$F/up/home/.local/bin/"
U=$F/down/home/.local/bin/torus-updates
assert_eq "installed" "$("$U" torus | cut -f1)" "nothing new: only the installed commit"
g "$F/up" commit -q --allow-empty -m "fix: two"
g "$F/up" commit -q --allow-empty -m "feat: three"
touch -d '2 hours ago' "$F/down/.git/FETCH_HEAD"
out=$("$U" torus)
assert_eq "installed feat: one|unsigned feat: three|unsigned fix: two" "$(cut -f1,3 <<< "$out" | tr '\t' ' ' | paste -sd'|')" "upstream commits after the installed one, newest first, unsigned ones marked"
assert_eq "" "$("$F/up/home/.local/bin/torus-updates" torus)" "a checkout without upstream prints nothing"
echo "changelog: ok"
