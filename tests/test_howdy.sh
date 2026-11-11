#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export TORUS_ROOT=$F
mkdir -p "$F/etc/pam.d" "$F/usr/lib/security"
printf '#%%PAM-1.0\nauth\t\tinclude\t\tsystem-auth\naccount\t\tinclude\t\tsystem-auth\nsession\t\tinclude\t\tsystem-auth\n' > "$F/etc/pam.d/sudo"
cp "$F/etc/pam.d/sudo" "$F/sudo.orig"
T=$REPO/home/.local/bin/torus-howdy

assert_fails "$T" setup
: > "$F/usr/lib/security/pam_howdy.so"
"$T" setup > /dev/null
assert_contains "$F/etc/pam.d/torus-face" "auth       sufficient   pam_howdy.so"
assert_contains "$F/etc/pam.d/torus-face" "pam_deny.so"
cmp -s "$F/etc/pam.d/sudo" "$F/sudo.orig" || fail "sudo untouched without --sudo"
"$T" setup --sudo > /dev/null
assert_eq "auth       sufficient   pam_howdy.so # torus-howdy" "$(sed -n 2p "$F/etc/pam.d/sudo")" "howdy before the first auth line"
assert_eq 1 "$(grep -c pam_howdy "$F/etc/pam.d/sudo")" "once"
"$T" setup --sudo > /dev/null
assert_eq 1 "$(grep -c pam_howdy "$F/etc/pam.d/sudo")" "still once"
assert_eq "lock: on
sudo: on" "$("$T" status)" "status"
"$T" off > /dev/null
[[ -e $F/etc/pam.d/torus-face ]] && fail "off removes the face stack"
cmp -s "$F/etc/pam.d/sudo" "$F/sudo.orig" || fail "off restores sudo byte for byte"
true
