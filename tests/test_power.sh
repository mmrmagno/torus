#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
T=$REPO/home/.local/bin/torus-power
mk() { mkdir -p "$F/$1/$2"; echo "$3" > "$F/$1/$2/type"; [[ -n ${4:-} ]] && echo "$4" > "$F/$1/$2/online"; true; }

mk desk AC Mains 1
assert_eq none "$(TORUS_POWER_SUPPLY=$F/desk "$T" status)" "desktop has no battery"
TORUS_POWER_SUPPLY=$F/desk "$T" on-battery && fail "desktop never counts as on battery"

mk lap BAT0 Battery; mk lap AC Mains 1
assert_eq ac "$(TORUS_POWER_SUPPLY=$F/lap "$T" status)" "laptop plugged in"
TORUS_POWER_SUPPLY=$F/lap "$T" on-battery && fail "plugged in is not on battery"
echo 0 > "$F/lap/AC/online"
assert_eq battery "$(TORUS_POWER_SUPPLY=$F/lap "$T" status)" "laptop unplugged"
TORUS_POWER_SUPPLY=$F/lap "$T" on-battery || fail "unplugged counts as on battery"
true
