#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export XDG_STATE_HOME=$F/state
S=$F/state/torus
T=$REPO/home/.local/bin/torus-mangohud
mkdir -p "$S/theme"

assert_eq off "$("$T" status)" "off by default"
"$T" apply
[[ -e $S/mangohud.conf ]] && fail "nothing written without a rendered theme"
printf 'fps\ngpu_color=89b4fa\n' > "$S/theme/mangohud.conf"
"$T" apply
assert_contains "$S/mangohud.conf" "gpu_color=89b4fa"
assert_contains "$S/mangohud.conf" "no_display"
assert_eq on "$("$T" toggle)" "toggle turns it on"
grep -q no_display "$S/mangohud.conf" && fail "on shows the overlay"
ino=$(stat -c %i "$S/mangohud.conf")
assert_eq off "$("$T" toggle)" "toggle turns it off"
assert_contains "$S/mangohud.conf" "no_display"
assert_eq "$ino" "$(stat -c %i "$S/mangohud.conf")" "written in place so MangoHud keeps watching the file"
"$T" on > /dev/null
printf 'fps\ngpu_color=cba6f7\n' > "$S/theme/mangohud.conf"
"$T" apply
assert_contains "$S/mangohud.conf" "gpu_color=cba6f7"
grep -q no_display "$S/mangohud.conf" && fail "an accent change keeps the overlay on"
assert_fails "$T" bogus
grep -q 'command -v mangohud > /dev/null && export MANGOHUD=1' "$REPO/home/.config/uwsm/env" || fail "env only when mangohud is installed"
