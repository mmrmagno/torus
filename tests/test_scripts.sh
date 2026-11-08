#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/stubs.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
unset XDG_PICTURES_DIR XDG_VIDEOS_DIR XDG_CONFIG_HOME XDG_DATA_HOME
export HOME=$F/home XDG_STATE_HOME=$F/home/.local/state STUB_LOG=$F/calls
mkdir -p "$HOME/Pictures" "$HOME/.local/share/Steam/steamapps"
mkscriptstubs "$F/bin"
export PATH=$F/bin:$PATH
B=$REPO/home/.local/bin

"$B/torus-shot" s
grep -q '^slurp' "$STUB_LOG" || fail "s: slurp"
grep -q '^grim -g 10,20 300x200 .*/Pictures/Screenshots/torus-.*\.png' "$STUB_LOG" || fail "s: grim geometry"
grep -q '^satty --filename .*torus-.*\.png' "$STUB_LOG" || fail "s: satty"

: > "$STUB_LOG"; "$B/torus-shot" m
grep -q '^grim -o DP-1 ' "$STUB_LOG" || fail "m: focused monitor"

: > "$STUB_LOG"; "$B/torus-shot" p
grep -qE '^grim [^-]' "$STUB_LOG" || fail "p: all monitors"

: > "$STUB_LOG"; "$B/torus-shot" sf
grep -q '^hyprpicker -r -z' "$STUB_LOG" || fail "sf: freeze"

: > "$STUB_LOG"; "$B/torus-shot" sc
grep -q '^tesseract' "$STUB_LOG" || fail "sc: tesseract"
grep -q '^wl-copy' "$STUB_LOG" || fail "sc: clipboard"

: > "$STUB_LOG"; "$B/torus-gamemode"
assert_eq on "$(cat "$XDG_STATE_HOME/torus/gamemode")" "gamemode on"
grep -q 'hyprctl eval .*animations' "$STUB_LOG" || fail "gamemode: animations off"
grep -q 'qs -c torus ipc call torus gamemode true' "$STUB_LOG" || fail "gamemode: shell told"
: > "$STUB_LOG"; "$B/torus-gamemode"
assert_eq off "$(cat "$XDG_STATE_HOME/torus/gamemode")" "gamemode off"
grep -q '^hyprctl reload' "$STUB_LOG" || fail "gamemode off: reload restores config"
grep -q 'qs -c torus ipc call torus gamemode false' "$STUB_LOG" || fail "gamemode off: shell told"

: > "$STUB_LOG"; "$B/torus-wmute"
grep -q '^wpctl set-mute 77 toggle' "$STUB_LOG" || fail "wmute: stream of focused window"

printf '"AppState"\n{\n\t"appid"\t\t"213670"\n\t"name"\t\t"South Park™: The Stick of Truth™"\n}\n' > "$HOME/.local/share/Steam/steamapps/appmanifest_213670.acf"
: > "$STUB_LOG"; STUB_ROFI_PICK="South Park™: The Stick of Truth™" "$B/torus-menu" games
assert_contains "$STUB_LOG.rofi-in" "South Park"
wait_for "$STUB_LOG" '^steam steam://rungameid/213670' || fail "games: launch by appid"

: > "$STUB_LOG"; STUB_ROFI_PICK=blue "$B/torus-menu" accent || true
grep -q '^rofi' "$STUB_LOG" || fail "accent menu: rofi"

: > "$STUB_LOG"; "$B/torus-record" toggle
grep -q '^gpu-screen-recorder .*-o .*/Videos/torus-.*\.mp4' "$STUB_LOG" || fail "record: start"

: > "$STUB_LOG"; STUB_ROFI_PICK=sf_marc "$B/torus-menu" hyprlock
assert_link "$XDG_STATE_HOME/torus/hyprlock-layout.conf" "$HOME/.config/hypr/hyprlock/sf_marc.conf"

rc=0; "$B/torus-menu" nope > /dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "unknown menu exit code"
