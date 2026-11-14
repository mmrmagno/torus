#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/Videos/Clips/hades" "$F/state/torus"
export PATH=$F/bin:$PATH HOME=$F XDG_STATE_HOME=$F/state XDG_CACHE_HOME=$F/cache XDG_CONFIG_HOME=$F/config XDG_VIDEOS_DIR=$F/Videos
printf '#!/bin/sh\nexit 0\n' > "$F/bin/qs"
printf '#!/bin/sh\nprintf "1145360\\tHades\\t0\\t0\\t\\n"\n' > "$F/bin/torus-games"
chmod +x "$F/bin/"*
P=$REPO/home/.local/bin/torus-play
echo '{"name": "Hades", "appid": "1145360"}' > "$F/state/torus/play-session.json"

echo one > "$F/Videos/Replay_1.mp4"; echo two > "$F/Videos/Replay_2.mp4"
"$P" saved "$F/Videos/Replay_1.mp4" > /dev/null
"$P" saved "$F/Videos/Replay_2.mp4" > /dev/null
assert_eq 2 "$(ls "$F/Videos/Clips/hades" | wc -l)" "two clips saved in the same second are both kept ($(ls "$F/Videos/Clips/hades" | paste -sd' '))"
assert_eq "one two" "$(cat "$F"/Videos/Clips/hades/*.mp4 | sort | paste -sd' ')" "neither clip overwrote the other"

echo part > "$F/Videos/Clips/hades/hades-cut-1.mp4.part.mp4"
ln -s "$F/gone.mp4" "$F/Videos/Clips/hades/vanished.mp4"
out=$("$P" library 2> "$F/err") || fail "the library listing crashed on a clip that went away: $(tail -1 "$F/err")"
grep -q 'part' <<< "$out" && fail "a half-written cut is listed as a clip"
assert_eq 2 "$(wc -l <<< "$out")" "only the two real clips are listed"
"$P" clips "" > /dev/null 2> "$F/err" || fail "the clip strip crashed on a clip that went away: $(tail -1 "$F/err")"
echo "clipsafe: ok"
