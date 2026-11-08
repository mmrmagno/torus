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

printf '#!/usr/bin/env bash\necho "gpu-screen-recorder $*" >> "$STUB_LOG"\nsleep 1\n' > "$F/bin/gpu-screen-recorder"
: > "$STUB_LOG"; "$B/torus-record" toggle
sleep 0.4
grep -q '^gpu-screen-recorder .*-o .*/Videos/torus-.*\.mp4' "$STUB_LOG" || fail "record: start"
[[ -s $XDG_STATE_HOME/torus/recording ]] || fail "record: marker while recording"
sleep 1.5
assert_file "$XDG_STATE_HOME/torus/recording"
[[ ! -s $XDG_STATE_HOME/torus/recording ]] || fail "record: marker must clear when the recorder exits"

: > "$STUB_LOG"; STUB_ROFI_PICK=sf_marc "$B/torus-menu" hyprlock
assert_link "$XDG_STATE_HOME/torus/hyprlock-layout.conf" "$HOME/.config/hypr/hyprlock/sf_marc.conf"
assert_eq hyprlock "$(cat "$XDG_STATE_HOME/torus/lock")" "hyprlock layout pick selects hyprlock"
: > "$STUB_LOG"; "$B/torus-lock" || true
grep -q '^hyprlock' "$STUB_LOG" || fail "lock: hyprlock mode runs hyprlock"
grep -q 'call torus lock' "$STUB_LOG" && fail "lock: hyprlock mode must not ask the shell"

: > "$STUB_LOG"; STUB_ROFI_PICK=torus "$B/torus-menu" hyprlock
assert_eq shell "$(cat "$XDG_STATE_HOME/torus/lock")" "torus pick selects shell lock"
: > "$STUB_LOG"; "$B/torus-lock" || true
grep -q '^grim -l 0 -o DP-1 ' "$STUB_LOG" || fail "lock: screenshot per monitor"
grep -q 'qs -c torus ipc call torus lock' "$STUB_LOG" || fail "lock: asks the shell"
grep -q '^hyprlock' "$STUB_LOG" && fail "lock: hyprlock ran although the shell locked"
: > "$STUB_LOG"; "$B/torus-lock" || true
grep -q 'call torus lock' "$STUB_LOG" && fail "lock: already locked must not lock again"
rm -f "$STUB_LOG.locked"
: > "$STUB_LOG"; STUB_QS=down "$B/torus-lock" || true
grep -q '^hyprlock' "$STUB_LOG" || fail "lock: falls back to hyprlock when the shell is down"
: > "$STUB_LOG"; STUB_QS=deny "$B/torus-lock" || true
grep -q '^hyprlock' "$STUB_LOG" || fail "lock: falls back to hyprlock when the shell never secures the session"

grep -Eq '^\s*inhibit_sleep\s*=\s*3\s*$' "$REPO/home/.config/hypr/hypridle.conf" || fail "hypridle: suspend must wait for a confirmed lock"

mkdir -p "$HOME/Documents/taxes" "$HOME/.secret"
echo x > "$HOME/Documents/taxes/2026.pdf"; echo x > "$HOME/.secret/key"
printf '#!/usr/bin/env bash\necho "xdg-open $*" >> "$STUB_LOG"\n' > "$F/bin/xdg-open"; chmod +x "$F/bin/xdg-open"
: > "$STUB_LOG"; STUB_ROFI_PICK="Documents/taxes/2026.pdf" "$B/torus-menu" files
grep -qx "Documents/taxes/2026.pdf" "$STUB_LOG.rofi-in" || fail "files: home files listed: $(head -3 "$STUB_LOG.rofi-in")"
grep -q "secret" "$STUB_LOG.rofi-in" && fail "files: hidden folders listed"
grep -q "^xdg-open $HOME/Documents/taxes/2026.pdf" "$STUB_LOG" || fail "files: pick opens the file"
printf '#!/usr/bin/env bash\necho "fd $*" >> "$STUB_LOG"\necho "Music/song.flac"\n' > "$F/bin/fd"; chmod +x "$F/bin/fd"
: > "$STUB_LOG"; STUB_ROFI_PICK="Music/song.flac" "$B/torus-menu" files
grep -q '^fd --type f' "$STUB_LOG" || fail "files: fd used when installed"
grep -qx "Music/song.flac" "$STUB_LOG.rofi-in" || fail "files: fd results listed"
rm "$F/bin/fd"

printf '#!/usr/bin/env bash\n[[ ${STUB_ROFI_RUNNING:-} == 1 && " $* " == *" rofi "* ]]\n' > "$F/bin/pgrep"; chmod +x "$F/bin/pgrep"
printf '#!/usr/bin/env bash\necho "pkill $*" >> "$STUB_LOG"\n' > "$F/bin/pkill"; chmod +x "$F/bin/pkill"
: > "$STUB_LOG"; STUB_ROFI_RUNNING=1 "$B/torus-menu" drun < /dev/null
grep -q '^pkill -x rofi' "$STUB_LOG" || fail "menu key closes an open rofi"
grep -q '^rofi' "$STUB_LOG" && fail "menu key must not open a second rofi"
: > "$STUB_LOG"; "$B/torus-menu" drun < /dev/null
grep -q '^rofi -show drun' "$STUB_LOG" || fail "menu opens when rofi is closed"

rc=0; "$B/torus-menu" nope > /dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "unknown menu exit code"
