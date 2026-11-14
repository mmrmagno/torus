#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/Videos/Clips/hades" "$F/Videos/Clips/counter-strike-2"
export PATH=$F/bin:$PATH HOME=$F XDG_STATE_HOME=$F/state XDG_CACHE_HOME=$F/cache XDG_CONFIG_HOME=$F/config XDG_VIDEOS_DIR=$F/Videos
printf '#!/bin/sh\nprintf "730\\tCounter-Strike 2\\t0\\t0\\t\\n1145360\\tHades\\t0\\t0\\t\\n"\n' > "$F/bin/torus-games"
printf '#!/bin/sh\nfor a; do o=$a; done; touch "$o"\n' > "$F/bin/ffmpeg"
chmod +x "$F/bin/torus-games" "$F/bin/ffmpeg"
P=$REPO/home/.local/bin/torus-play
H=$F/Videos/Clips/hades/hades-2026-11-10-100000.mp4
A=$F/Videos/Clips/counter-strike-2/counter-strike-2-ace-2026-11-12-100000.mp4
M=$F/Videos/Clips/counter-strike-2/counter-strike-2-2026-11-11-100000.mp4
for f in "$H" "$A" "$M"; do head -c 1000 /dev/urandom > "$f"; done
touch -d '2026-11-10 10:00' "$H"; touch -d '2026-11-11 10:00' "$M"; touch -d '2026-11-12 10:00' "$A"

out=$("$P" library)
assert_eq "counter-strike-2-ace-2026-11-12-100000.mp4|ace|counter-strike-2|Counter-Strike 2|0
counter-strike-2-2026-11-11-100000.mp4||counter-strike-2|Counter-Strike 2|0
hades-2026-11-10-100000.mp4||hades|Hades|0" "$(awk -F'\t' '{ n = split($1, p, "/"); print p[n] "|" $5 "|" $6 "|" $7 "|" $8 }' <<< "$out")" "every game's clips, newest first, with game and auto badge"
[[ -z $(cut -f3 <<< "$out" | tr -d '\n') ]] || fail "library lists at once, without making thumbnails"
assert_eq 3 "$("$P" thumbs)" "thumbs makes the missing ones"
assert_eq 0 "$("$P" thumbs)" "and only once"
[[ -n $("$P" library | head -1 | cut -f3) ]] || fail "thumb listed once it exists"

assert_eq on "$("$P" fav "$H" on)" "star"
assert_eq "1" "$("$P" library | awk -F'\t' -v h="$H" '$1 == h { print $8 }')" "star survives a restart (stored, not in memory)"
jq -e --arg h "$H" 'index($h) != null' "$F/state/torus/clip-favorites.json" > /dev/null || fail "favorites are a list of paths"
assert_eq off "$("$P" fav "$H" toggle)" "toggle"
assert_eq on "$("$P" fav "$H" toggle)" "toggle back"
assert_eq "1" "$("$P" clips 1145360 | cut -f6)" "the dock's clip strip knows the star too"

N=$("$P" rename "$H" "boss fight")
assert_eq "$F/Videos/Clips/hades/boss fight.mp4" "$N" "rename keeps the folder and the extension"
[[ -f $N && ! -e $H ]] || fail "rename moved the file"
jq -e --arg n "$N" 'index($n) != null' "$F/state/torus/clip-favorites.json" > /dev/null || fail "a renamed favorite keeps its star"
assert_eq "$N" "$("$P" rename "$N" "boss fight.mp4")" "the same name is fine"
assert_fails "$P" rename "$N" "../escape"
assert_fails "$P" rename "$N" ""
assert_fails "$P" rename "$N" ".hidden"
assert_fails "$P" rename "$F/state/torus/clip-favorites.json" "x"
cp "$N" "$F/Videos/Clips/hades/taken.mp4"
assert_fails "$P" rename "$N" "taken"
[[ -f $N ]] || fail "a refused rename left the clip alone"
echo "library: ok"
