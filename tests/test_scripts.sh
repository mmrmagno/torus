#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/stubs.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
unset XDG_PICTURES_DIR XDG_VIDEOS_DIR XDG_CONFIG_HOME XDG_DATA_HOME
export HOME=$F/home XDG_STATE_HOME=$F/home/.local/state STUB_LOG=$F/calls XDG_RUNTIME_DIR=$F/run
mkdir -p -m 700 "$F/run"
mkdir -p "$HOME/Pictures" "$HOME/.local/share/Steam/steamapps"
mkscriptstubs "$F/bin"
export PATH=$F/bin:$PATH
B=$REPO/home/.local/bin

"$B/torus-shot" s
grep -q '^slurp' "$STUB_LOG" || fail "s: slurp"
grep -q '^grim -g 10,20 300x200 .*/Pictures/Screenshots/torus-.*\.png' "$STUB_LOG" || fail "s: grim geometry"
grep -q '^qs -c torus ipc call torus screenshotShow .*/Pictures/Screenshots/torus-.*\.png' "$STUB_LOG" || fail "s: island shows the shot"
grep -q '^satty' "$STUB_LOG" && fail "s: satty only on request"
: > "$STUB_LOG"; STUB_QS=down "$B/torus-shot" s; sleep 0.5
grep -q '^satty --filename .*torus-.*\.png' "$STUB_LOG" || fail "s: satty when the shell is not running"

: > "$STUB_LOG"; "$B/torus-shot" m
grep -q '^grim -o DP-1 ' "$STUB_LOG" || fail "m: focused monitor"

: > "$STUB_LOG"; "$B/torus-shot" p
grep -qE '^grim [^-]' "$STUB_LOG" || fail "p: all monitors"

: > "$STUB_LOG"; "$B/torus-shot" sf
grep -q '^hyprpicker -r -z' "$STUB_LOG" || fail "sf: freeze"

mv "$F/bin/hyprpicker" "$F/bin/hyprpicker.real"; mv "$F/bin/slurp" "$F/bin/slurp.real"; mv "$F/bin/grim" "$F/bin/grim.real"
printf '#!/usr/bin/env bash\necho "hyprpicker $*" >> "$STUB_LOG"\nexec -a torus-test-picker sleep 30\n' > "$F/bin/hyprpicker"
printf '#!/usr/bin/env bash\necho "slurp $*" >> "$STUB_LOG"\necho "10,20 300x200"\n' > "$F/bin/slurp"
printf '#!/usr/bin/env bash\nexit 1\n' > "$F/bin/grim"
chmod +x "$F/bin/hyprpicker" "$F/bin/slurp" "$F/bin/grim"
: > "$STUB_LOG"; "$B/torus-shot" sf || true
sleep 0.3
if pids=$(/usr/bin/pgrep -f '^torus-test-picker '); then kill $pids; fail "sf: a failed capture must not leave the frozen picker running"; fi
mv "$F/bin/grim.real" "$F/bin/grim"
printf '#!/usr/bin/env bash\necho "slurp $*" >> "$STUB_LOG"\nsleep 1\necho "10,20 300x200"\n' > "$F/bin/slurp"
: > "$STUB_LOG"; "$B/torus-shot" s & first=$!
sleep 0.3; "$B/torus-shot" s; wait "$first"
(( $(grep -c '^slurp' "$STUB_LOG") == 1 )) || fail "s: a second press while selecting must not stack another selection"
mv "$F/bin/hyprpicker.real" "$F/bin/hyprpicker"; mv "$F/bin/slurp.real" "$F/bin/slurp"

printf '#!/usr/bin/env bash\necho "tesseract $*" >> "$STUB_LOG"\n[[ $1 == --list-langs ]] && printf "List of available languages:\\neng\\nosd\\n" || printf "Total fo-\\nr you\\n"\n' > "$F/bin/tesseract"; chmod +x "$F/bin/tesseract"
: > "$STUB_LOG"; "$B/torus-shot" sc
grep -q 'tesseract .* -l eng$' "$STUB_LOG" || fail "sc: only installed languages: $(grep tesseract "$STUB_LOG")"
assert_eq "Total for you" "$(cat "$XDG_RUNTIME_DIR/torus-ocr.txt" | tr '\n' ' ' | sed 's/ $//')" "sc: hyphenation joined"
grep -q '^tesseract' "$STUB_LOG" || fail "sc: tesseract"
grep -q '^wl-copy' "$STUB_LOG" || fail "sc: clipboard"

: > "$STUB_LOG"; "$B/torus-gamemode"
assert_eq on "$(cat "$XDG_STATE_HOME/torus/gamemode")" "gamemode on"
grep -q 'hyprctl eval torus_gamemode_apply()' "$STUB_LOG" || fail "gamemode: effects off"
grep -q 'qs -c torus ipc call torus gamemode true' "$STUB_LOG" || fail "gamemode: shell told"
: > "$STUB_LOG"; "$B/torus-gamemode"
assert_eq off "$(cat "$XDG_STATE_HOME/torus/gamemode")" "gamemode off"
grep -q '^hyprctl reload' "$STUB_LOG" || fail "gamemode off: reload restores config"
grep -q 'qs -c torus ipc call torus gamemode false' "$STUB_LOG" || fail "gamemode off: shell told"

: > "$STUB_LOG"; "$B/torus-wmute"
grep -q '^wpctl set-mute 77 toggle' "$STUB_LOG" || fail "wmute: stream of focused window"

for gone in games style wallpaper accent animations; do
  "$B/torus-menu" "$gone" > /dev/null 2>&1 && fail "rofi menu $gone is retired (game hub and theme studio do it)"
done

printf '#!/usr/bin/env bash\necho "gpu-screen-recorder $*" >> "$STUB_LOG"\nsleep 1\n' > "$F/bin/gpu-screen-recorder"
: > "$STUB_LOG"; "$B/torus-record" toggle
sleep 0.4
grep -q '^gpu-screen-recorder .*-o .*/Videos/torus-.*\.mp4' "$STUB_LOG" || fail "record: start"
[[ -s $XDG_STATE_HOME/torus/recording ]] || fail "record: marker while recording"
sleep 1.5
assert_file "$XDG_STATE_HOME/torus/recording"
[[ ! -s $XDG_STATE_HOME/torus/recording ]] || fail "record: marker must clear when the recorder exits"

cat > "$F/bin/gpu-screen-recorder" <<'S'
#!/usr/bin/env bash
if [[ $1 == --list-audio-devices ]]; then
  printf 'default_output|Default output\ndefault_input|Default input\nalsa_output.usb-a.monitor|Monitor of A\nalsa_input.usb-mic|USB Mic\n'
  exit 0
fi
echo "gpu-screen-recorder $*" >> "$STUB_LOG"
S
chmod +x "$F/bin/gpu-screen-recorder"
assert_eq "default_input alsa_input.usb-mic" "$("$B/torus-record" replay-mics | cut -f1 | tr '\n' ' ' | sed 's/ $//')" "replay mics: inputs only, no monitors"
: > "$STUB_LOG"; "$B/torus-record" replay-save; sleep 0.3
grep -q -- '-a default_output -c mp4 -r 60' "$STUB_LOG" || fail "replay: desktop sound only by default"
"$B/torus-record" replay-mic alsa_input.usb-mic
assert_eq alsa_input.usb-mic "$("$B/torus-record" replay-mic)" "replay mic remembered"
: > "$STUB_LOG"; "$B/torus-record" replay-save; sleep 0.3
grep -q -- '-a default_output|alsa_input.usb-mic -c mp4' "$STUB_LOG" || fail "replay: mic merged into the sound track: $(cat "$STUB_LOG")"
"$B/torus-record" replay-mic nope 2> /dev/null && fail "replay: unknown input must be refused"
"$B/torus-record" replay-mic off
assert_eq "" "$("$B/torus-record" replay-mic)" "replay mic off"
mkdir -p "$F/busy"; printf '#!/bin/sh\nexit 0\n' > "$F/busy/pgrep"; chmod +x "$F/busy/pgrep"
echo '{"name": "Counter-Strike 2", "replay": true}' > "$XDG_STATE_HOME/torus/play-session.json"
: > "$STUB_LOG"; PATH=$F/busy:$PATH "$B/torus-record" replay-mic alsa_input.usb-mic
grep -q 'pkill' "$STUB_LOG" && fail "changing the mic during a game stopped the game's own replay buffer: $(cat "$STUB_LOG")"
grep -q 'gpu-screen-recorder' "$STUB_LOG" && fail "changing the mic during a game started a plain buffer"
grep -q 'next game' "$STUB_LOG" || fail "it says the mic applies from the next game: $(cat "$STUB_LOG")"
: > "$STUB_LOG"; "$B/torus-record" replay-save; sleep 0.3
grep -q -- '-r 60 -sc .*torus-play-saved' "$STUB_LOG" || fail "a buffer the save key starts during a game files its clips under the game: $(cat "$STUB_LOG")"
rm -f "$XDG_STATE_HOME/torus/play-session.json"
: > "$STUB_LOG"; PATH=$F/busy:$PATH "$B/torus-record" replay-mic off
grep -q 'gpu-screen-recorder -w portal' "$STUB_LOG" || fail "outside a game the plain buffer restarts with the new mic: $(cat "$STUB_LOG")"

mkdir -p "$HOME/.config/hypr/hyprlock"; : > "$HOME/.config/hypr/hyprlock/sf_marc.conf"
: > "$STUB_LOG"; STUB_ROFI_PICK=sf_marc "$B/torus-menu" hyprlock
assert_link "$XDG_STATE_HOME/torus/hyprlock-layout.conf" "$HOME/.config/hypr/hyprlock/sf_marc.conf"
assert_eq hyprlock "$(cat "$XDG_STATE_HOME/torus/lock")" "hyprlock layout pick selects hyprlock"
assert_eq sf_marc "$("$B/torus-lockstyle" get)" "lockstyle reads the pick back"
: > "$STUB_LOG"; "$B/torus-lock" || true
grep -q '^hyprlock' "$STUB_LOG" || fail "lock: hyprlock mode runs hyprlock"
grep -q 'call torus lock' "$STUB_LOG" && fail "lock: hyprlock mode must not ask the shell"

: > "$STUB_LOG"; STUB_ROFI_PICK=torus "$B/torus-menu" hyprlock
assert_eq shell "$(cat "$XDG_STATE_HOME/torus/lock")" "torus pick selects shell lock"
assert_eq torus "$("$B/torus-lockstyle" get)" "lockstyle: torus"
"$B/torus-lockstyle" nope 2> /dev/null && fail "lockstyle refuses unknown layouts"
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
