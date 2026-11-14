#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"
command -v ffmpeg > /dev/null || { echo "clipcut: skipped (no ffmpeg)"; exit 0; }

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/trash" "$F/Clips/game"
printf '#!/bin/sh\n[ "$1" = put ] && mv "$2" "%s/trash/"\n' "$F" > "$F/bin/torus-trash"
chmod +x "$F/bin/torus-trash"
export PATH=$F/bin:$PATH XDG_CACHE_HOME=$F/cache XDG_STATE_HOME=$F/state
S=$REPO/home/.local/bin/torus-clipcut
C=$F/Clips/game/game-2026-11-13-120000.mp4
ffmpeg -v error -f lavfi -i testsrc=s=320x180:r=30:d=10 -f lavfi -i sine=d=10 -c:v libx264 -g 60 -keyint_min 60 -sc_threshold 0 -pix_fmt yuv420p -c:a aac -shortest "$C"
sum=$(md5sum < "$C")

info=$("$S" info "$C")
assert_eq "10 1 1" "$(jq -r '"\(.duration | floor) \(.audio) \(.video)"' <<< "$info")" "probe"
assert_eq "0 2 4 6 8" "$(jq -r '[.keyframes[] | floor] | join(" ")' <<< "$info")" "keyframes every 2 s"
assert_eq 12 "$(jq -r '.strip | length' <<< "$info")" "filmstrip frames"

out=$("$S" cut "$C" 3.3 6)
p=$(jq -r .path <<< "$out")
assert_eq "$F/Clips/game/game-2026-11-13-120000-cut-1.mp4" "$p" "new file next to the original"
assert_eq "2" "$(jq -r '.start | floor' <<< "$out")" "in point snaps back to the keyframe"
d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$p")
awk -v d="$d" 'BEGIN { exit !(d >= 2.6 && d <= 4.8) }' || fail "cut length within one keyframe interval of 2.7 s: $d"
assert_eq 1 "$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$p" | wc -l)" "audio stream kept"
assert_eq "$sum" "$(md5sum < "$C")" "original untouched"
[[ $(jq -r .path <<< "$("$S" cut "$C" 0 4)") == *-cut-2.mp4 ]] || fail "a second cut gets the next number"
assert_fails "$S" cut "$C" 5 5.2

mkdir -p "$F/state/torus"
printf '["%s"]' "$C" > "$F/state/torus/clip-favorites.json"
assert_fails "$S" cut "$C" 4 8 --keep-only
grep -q "is a favorite" <<< "$("$S" cut "$C" 4 8 --keep-only 2>&1 || true)" || fail "says why a favorite keeps its original"
assert_eq "$sum" "$(md5sum < "$C")" "a favorite's original is never replaced"
rm "$F/state/torus/clip-favorites.json"
out=$("$S" cut "$C" 4 8 --keep-only)
assert_eq "$C:true" "$(jq -r '"\(.path):\(.replaced)"' <<< "$out")" "keep only replaces the original"
[[ -f $F/trash/$(basename "$C") ]] || fail "the old original goes to the trash through torus-trash, so Undo and the trash meter see it"
d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$C")
awk -v d="$d" 'BEGIN { exit !(d >= 3.9 && d <= 4.2) }' || fail "replaced clip is the 4 s part: $d"
echo "clipcut: ok"
