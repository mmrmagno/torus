#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export XDG_CACHE_HOME=$F/cache XDG_PICTURES_DIR=$F/Pictures XDG_VIDEOS_DIR=$F/Videos HOME=$F/home
C=$F/cache/torus
mkdir -p "$C/thumbs" "$C/clip" "$C/clip-strip" "$C/art" "$F/Pictures/Screenshots" "$F/Videos/Clips/hades" "$F/bin" "$F/home"
printf '#!/usr/bin/env bash\n[[ -n ${STUB_CLIPHIST_FAIL:-} ]] && exit 1\nprintf "1\\tkept entry\\n2\\t[[ binary data 1 KiB png 10x10 ]]\\n"\n' > "$F/bin/cliphist"
chmod +x "$F/bin/cliphist"
export PATH=$F/bin:$PATH
P=$REPO/home/.local/bin/torus-prune
old() { touch -d '2 days ago' "$@"; }

shot=$F/Pictures/Screenshots/a.png; echo x > "$shot"
clip=$F/Videos/Clips/hades/c.mp4; echo x > "$clip"
live_png=$C/thumbs/$(printf '%s:%s' "$shot" "$(find "$shot" -printf '%T@')" | md5sum | cut -d' ' -f1).png
live_jpg=$C/thumbs/$(printf '%s' "$clip" | md5sum | cut -d' ' -f1).jpg
live_strip=$C/clip-strip/$(python3 -c 'import hashlib,os,sys; p=sys.argv[1]; print(hashlib.md5((os.path.abspath(p)+str(os.path.getmtime(p))).encode()).hexdigest()[:16])' "$clip")
live_clip=$C/clip/$(printf '1\tkept entry' | md5sum | cut -d' ' -f1).img
mkdir -p "$live_strip" "$C/clip-strip/deadbeefdeadbeef"
echo x > "$live_strip/00.jpg"; echo x > "$C/clip-strip/deadbeefdeadbeef/00.jpg"
for f in "$live_png" "$live_jpg" "$live_clip" "$C/thumbs/gone.png" "$C/thumbs/gone.jpg" "$C/clip/gone.img" "$C/thumbs/notes.txt" "$C/art/keep.png"; do echo x > "$f"; done
echo x > "$C/thumbs/fresh.png"
old "$C"/thumbs/*.png "$C"/thumbs/*.jpg "$C"/thumbs/notes.txt "$C"/clip/*.img "$C"/clip-strip/* "$C/art/keep.png"
touch "$C/thumbs/fresh.png"
ln -s "$shot" "$C/thumbs/link.png"

out=$("$P" --dry-run)
grep -q 'would remove 4 cached files' <<< "$out" || fail "dry run counts: $out"
[[ -e $C/thumbs/gone.png ]] || fail "dry run removed something"
"$P" > /dev/null
for f in "$C/thumbs/gone.png" "$C/thumbs/gone.jpg" "$C/clip/gone.img" "$C/clip-strip/deadbeefdeadbeef"; do assert_absent "$f"; done
for f in "$live_png" "$live_jpg" "$live_clip" "$live_strip/00.jpg" "$C/thumbs/fresh.png" "$C/thumbs/notes.txt" "$C/art/keep.png" "$shot" "$clip"; do [[ -e $f ]] || fail "removed a file it must keep: $f"; done
[[ -L $C/thumbs/link.png ]] || fail "touched a symlink"

echo x > "$C/clip/gone2.img"; old "$C/clip/gone2.img"
STUB_CLIPHIST_FAIL=1 "$P" > /dev/null
[[ -e $C/clip/gone2.img ]] || fail "a failing cliphist must not prune clipboard thumbs"
echo x > "$C/thumbs/gone3.png"; old "$C/thumbs/gone3.png"
chmod 000 "$(dirname "$shot")"
"$P" > /dev/null
chmod 755 "$(dirname "$shot")"
[[ -e $C/thumbs/gone3.png && -e $live_png ]] || fail "an unreadable screenshot folder made every preview look orphaned"
assert_fails "$P" --everything
grep -q 'OnCalendar=weekly' "$REPO/home/.config/systemd/user/torus-prune.timer" || fail "weekly timer"
grep -q 'enable --now torus-prune.timer' "$REPO/home/.local/bin/torus" || fail "setup enables the timer"
echo "prune: ok"
