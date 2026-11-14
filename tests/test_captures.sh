#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/pics/Screenshots" "$F/vids" "$F/bin"
export XDG_PICTURES_DIR=$F/pics XDG_VIDEOS_DIR=$F/vids XDG_CACHE_HOME=$F/cache STUB_LOG=$F/calls
cat > "$F/bin/ffmpeg" <<'S'
#!/usr/bin/env bash
echo "ffmpeg $*" >> "$STUB_LOG"
for a; do last=$a; done
printf jpg > "$last"
S
chmod +x "$F/bin/ffmpeg"
export PATH=$F/bin:$PATH
T=$REPO/home/.local/bin/torus-captures

printf png > "$F/pics/Screenshots/old.png"; touch -d '2026-11-01 10:00' "$F/pics/Screenshots/old.png"
printf mp4 > "$F/vids/torus-rec.mp4"; touch -d '2026-11-05 10:00' "$F/vids/torus-rec.mp4"
printf png > "$F/pics/Screenshots/new.png"; touch -d '2026-11-09 10:00' "$F/pics/Screenshots/new.png"
printf txt > "$F/vids/notes.txt"
out=$("$T")
assert_eq "new.png torus-rec.mp4 old.png" "$(cut -f4 <<< "$out" | xargs -n1 basename | tr '\n' ' ' | sed 's/ $//')" "newest first, images and videos, other files ignored"
assert_eq "image video image" "$(cut -f1 <<< "$out" | tr '\n' ' ' | sed 's/ $//')" "kinds"
thumb=$(awk -F'\t' '$1 == "video" {print $5}' <<< "$out")
[[ -s $thumb && $thumb == "$F/cache/torus/thumbs/"*.jpg ]] || fail "video thumbnail cached: $thumb"
: > "$F/calls"; "$T" > /dev/null
assert_eq "" "$(cat "$F/calls")" "thumbnail made once"
img=$(awk -F'\t' '$4 ~ /new.png$/ {print $5}' <<< "$out")
[[ -s $img && $img == "$F/cache/torus/thumbs/"*.png ]] || fail "screenshots get a small cached thumbnail: $img"
assert_eq 1 "$("$T" 1 | wc -l)" "limit"
mkdir -p "$F/vids/Clips/hades"
printf mp4 > "$F/vids/Clips/hades/hades-1.mp4"; touch -d '2026-11-10 10:00' "$F/vids/Clips/hades/hades-1.mp4"
out=$("$T")
assert_eq "clip hades-1.mp4" "$(head -1 <<< "$out" | awk -F'\t' '{print $1}') $(head -1 <<< "$out" | cut -f4 | xargs basename)" "game clips listed from Clips subfolders"
[[ -s $(head -1 <<< "$out" | cut -f5) ]] || fail "game clip thumbnail"
mkdir -p "$F/state/torus"
printf '["%s"]\n' "$F/vids/Clips/hades/hades-1.mp4" > "$F/state/torus/clip-favorites.json"
assert_eq "1 0" "$(XDG_STATE_HOME=$F/state "$T" | awk -F'\t' 'NR<=2 {print $6}' | paste -sd' ')" "favorites are marked so the studio never deletes them"
true
