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

printf '#!/usr/bin/env bash\necho "powerprofilesctl $*" >> "$STUB_LOG"\nf=$XDG_STATE_HOME/pp; [[ $1 == get ]] && { cat "$f" 2> /dev/null || echo balanced; exit 0; }; [[ $1 == set ]] && echo "$2" > "$f"\n' > "$F/bin/powerprofilesctl"
chmod +x "$F/bin/powerprofilesctl"
echo power-saver > "$XDG_STATE_HOME/pp"
"$G" auto-on
assert_eq performance "$(cat "$XDG_STATE_HOME/pp")" "a game switches to performance"
"$G" auto-off
assert_eq power-saver "$(cat "$XDG_STATE_HOME/pp")" "and back to what it was"
echo performance > "$XDG_STATE_HOME/pp"
"$G" auto-on; "$G" auto-off
assert_eq performance "$(cat "$XDG_STATE_HOME/pp")" "already performance stays performance"
echo balanced > "$XDG_STATE_HOME/pp"
"$G" auto-on
echo power-saver > "$XDG_STATE_HOME/pp"
"$G" auto-off
assert_eq power-saver "$(cat "$XDG_STATE_HOME/pp")" "a profile I picked during the game is kept"
mkdir -p "$F/sh"
cp "$G" "$F/sh/"
printf '#!/bin/sh\necho "torus-play $*" >> "%s/play"\n' "$F" > "$F/sh/torus-play"; chmod +x "$F/sh/torus-play"
"$F/sh/torus-gamemode" auto-off; sleep 0.3
assert_eq "torus-play end" "$(cat "$F/play")" "leaving fullscreen only asks torus-play to end (it keeps the session while the game window is open)"
: > "$F/play"; "$F/sh/torus-gamemode" auto-off closed; sleep 0.3
assert_eq "torus-play end --closed" "$(cat "$F/play")" "a closed game ends the session"

