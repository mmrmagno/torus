#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin"
export XDG_STATE_HOME=$F/state XDG_RUNTIME_DIR=$F STUB_LOG=$F/calls PATH=$F/bin:$PATH TORUS_RELOAD_SETTLE=0
for c in hyprctl qs notify-send; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$STUB_LOG"\n' "$c" > "$F/bin/$c"; done
chmod +x "$F/bin/"*
G=$REPO/home/.local/bin/torus-gamemode
mode() { "$G" status; }

"$G" auto-on
assert_eq auto "$(mode)" "a game turns it on"
grep -q "hyprctl eval torus_gamemode_apply()" "$STUB_LOG" || fail "effects off through the shared Lua function"
grep -q "notify-send" "$STUB_LOG" && fail "automatic game mode is silent"
"$G" auto-off
assert_eq off "$(mode)" "closing the game turns automatic game mode off"
grep -q "hyprctl reload" "$STUB_LOG" || fail "off reloads the normal config"

"$G"
assert_eq on "$(mode)" "manual toggle on"
"$G" auto-off
assert_eq on "$(mode)" "a game closing never turns off game mode you switched on yourself"
"$G" auto-on
assert_eq on "$(mode)" "still on"
"$G"
assert_eq off "$(mode)" "manual toggle off"
grep -q 'notify-send .*Game mode' "$STUB_LOG" || fail "manual toggles say so"
