#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/sounds"
export XDG_STATE_HOME=$F/state PATH=$F/bin:$PATH STUB_LOG=$F/calls TORUS_SOUNDS=$F/sounds
printf '#!/usr/bin/env bash\necho "pw-play $*" >> "$STUB_LOG"\n' > "$F/bin/pw-play"; chmod +x "$F/bin/pw-play"
for f in audio-volume-change service-logout service-login camera-shutter trash-empty device-added device-removed message-new-instant dialog-warning bell dialog-error network-connectivity-established network-connectivity-lost power-plug power-unplug; do : > "$F/sounds/$f.oga"; done
T=$REPO/home/.local/bin/torus-sound

assert_eq off "$("$T" status)" "off by default"
"$T" play open
sleep 0.2
[[ -e $STUB_LOG ]] && fail "silent while off"
assert_eq on "$("$T" on)" "on"
for ev in open lock unlock shot; do "$T" play $ev; done
for _ in $(seq 20); do [[ $(grep -c . "$STUB_LOG" 2> /dev/null) == 4 ]] && break; sleep 0.1; done
grep -q "pw-play --volume 0.35 $F/sounds/audio-volume-change.oga" "$STUB_LOG" || fail "panel click: $(cat "$STUB_LOG")"
grep -q "service-logout.oga" "$STUB_LOG" || fail "lock chime"
grep -q "service-login.oga" "$STUB_LOG" || fail "unlock chime"
grep -q "camera-shutter.oga" "$STUB_LOG" || fail "shutter"
: > "$STUB_LOG"
for ev in delete record-start record-stop notify critical name:bell; do "$T" play $ev; done
: > "$F/custom.oga"; "$T" play "file:$F/custom.oga"
for _ in $(seq 20); do [[ $(grep -c . "$STUB_LOG" 2> /dev/null) == 7 ]] && break; sleep 0.1; done
for f in trash-empty device-added device-removed message-new-instant dialog-warning bell custom; do grep -q "$f.oga" "$STUB_LOG" || fail "$f played"; done
assert_fails "$T" play "name:../../etc/passwd"
"$T" play "file:relative.oga"
: > "$STUB_LOG"
for ev in tick error online offline plug unplug; do "$T" play $ev; done
for _ in $(seq 20); do [[ $(grep -c . "$STUB_LOG" 2> /dev/null) == 6 ]] && break; sleep 0.1; done
for f in dialog-error network-connectivity-established network-connectivity-lost power-plug power-unplug; do grep -q "$f.oga" "$STUB_LOG" || fail "$f played"; done
printf '#!/usr/bin/env bash\n[[ $1 == get-default-sink ]] && echo dac; [[ $1 == list ]] && printf "58\\tdac\\tPipeWire\\ts32le 2ch 48000Hz\\tSUSPENDED\\n"; exit 0\n' > "$F/bin/pactl"
printf '#!/usr/bin/env bash\necho "ffmpeg $*" >> "$STUB_LOG"; for a; do o=$a; done; echo x > "$o"\n' > "$F/bin/ffmpeg"
chmod +x "$F/bin/pactl" "$F/bin/ffmpeg"
export XDG_CACHE_HOME=$F/cache
: > "$STUB_LOG"
"$T" play tick
for _ in $(seq 20); do grep -q pw-play "$STUB_LOG" && break; sleep 0.1; done
grep -q 'ffmpeg .*adelay=350' "$STUB_LOG" || fail "a sleeping output gets a lead-in"
grep -q "pw-play --volume 0.3 $F/cache/torus/sounds/audio-volume-change-lead.wav" "$STUB_LOG" || fail "the lead-in copy plays: $(cat "$STUB_LOG")"
: > "$STUB_LOG"
"$T" play tick
for _ in $(seq 20); do grep -q pw-play "$STUB_LOG" && break; sleep 0.1; done
grep -q ffmpeg "$STUB_LOG" && fail "the lead-in copy is made once"
sed -i 's/SUSPENDED/RUNNING/' "$F/bin/pactl"
: > "$STUB_LOG"
"$T" play tick
for _ in $(seq 20); do grep -q pw-play "$STUB_LOG" && break; sleep 0.1; done
grep -q "pw-play --volume 0.3 $F/sounds/audio-volume-change.oga" "$STUB_LOG" || fail "an awake output plays at once"
assert_fails "$T" play bogus
"$T" off > /dev/null
assert_eq off "$("$T" status)" "off again"
grep -q 'torus-sound play shot' "$REPO/home/.local/bin/torus-shot" || fail "screenshots play the shutter"
