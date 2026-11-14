#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/trash" "$F/Videos/Clips/hades" "$F/Videos/Clips/celeste"
export PATH=$F/bin:$PATH HOME=$F XDG_STATE_HOME=$F/state XDG_CACHE_HOME=$F/cache XDG_CONFIG_HOME=$F/config XDG_VIDEOS_DIR=$F/Videos TORUS_CLIP_GB=1000
printf '#!/bin/sh\n[ "$1" = put ] && mv "$2" "%s/trash/"\n' "$F" > "$F/bin/torus-trash"
printf '#!/bin/sh\necho "qs $*" >> "%s/qs"\n' "$F" > "$F/bin/qs"
printf '#!/bin/sh\nprintf "1145360\\tHades\\t0\\t0\\t\\n"\n' > "$F/bin/torus-games"
chmod +x "$F/bin/"*
P=$REPO/home/.local/bin/torus-play
d=0
for g in hades celeste hades celeste hades; do
  d=$((d + 1))
  f=$F/Videos/Clips/$g/$g-2026-11-0$d-100000.mp4
  head -c 5500 /dev/zero > "$f"
  touch -d "2026-11-0$d 10:00" "$f"
done
old=$F/Videos/Clips/hades/hades-2026-11-01-100000.mp4
"$P" fav "$old" on > /dev/null

assert_eq 0 "$("$P" budget)" "off by default"
assert_eq "" "$("$P" cleanup)" "nothing happens while off"
[[ -z $(ls "$F/trash") ]] || fail "off trashes nothing"
assert_fails "$P" budget 30
assert_eq 25 "$("$P" budget 25)" "25 GB (scaled: 25000 bytes)"
out=$("$P" cleanup)
assert_eq "celeste-2026-11-02-100000.mp4" "$(xargs -r -n1 basename <<< "$out" | paste -sd' ')" "oldest non-favorite first, until under budget"
[[ -f $old ]] || fail "a favorite is never trashed"
[[ -f $F/trash/celeste-2026-11-02-100000.mp4 ]] || fail "through torus-trash, never rm"
grep -q "islandFlash notification Clips over 25 GB: 1 old clip to the trash" "$F/qs" || fail "the island says what went: $(cat "$F/qs")"
assert_eq "" "$("$P" cleanup)" "under budget now"

for f in "$F"/Videos/Clips/*/*.mp4; do [[ $f == "$old" ]] || rm "$f"; done
rm -f "$F/trash/"*
for i in 1 2 3; do f=$F/Videos/Clips/hades/fav$i.mp4; head -c 10000 /dev/zero > "$f"; touch -d "2026-11-0$i 09:00" "$f"; "$P" fav "$f" on > /dev/null; done
new=$F/Videos/Clips/hades/hades-2026-11-14-100000.mp4
head -c 5000 /dev/zero > "$new"
: > "$F/qs"
assert_eq "" "$("$P" cleanup)" "favorites alone over the budget: nothing goes"
[[ -f $new ]] || fail "the clip just saved was trashed because the favorites fill the budget"
grep -q "favorites alone" "$F/qs" || fail "the island says why nothing went: $(cat "$F/qs")"
"$P" cleanup > /dev/null
assert_eq 1 "$(grep -c "favorites alone" "$F/qs")" "it says so once a day, not after every clip"
rm "$F/Videos/Clips/hades/fav1.mp4" "$F/Videos/Clips/hades/fav2.mp4"
for i in 1 2 3 4; do f=$F/Videos/Clips/celeste/c$i.mp4; head -c 3000 /dev/zero > "$f"; touch -d "2026-11-0$i 08:00" "$f"; done
printf '#!/bin/sh
[ "$1" = put ] || exit 0
sleep 0.3
[ -e "$2" ] || exit 1
mv "$2" "%s/trash/"
' "$F" > "$F/bin/torus-trash"
"$P" cleanup > "$F/c1" 2> "$F/e1" & a=$!
"$P" cleanup > "$F/c2" 2> "$F/e2" & b=$!
wait $a; wait $b
[[ -f $new ]] || fail "a clip under ten minutes old is never trashed"
! grep -q Traceback "$F/e1" "$F/e2" || fail "two cleanups at once crash: $(cat "$F/e1" "$F/e2")"
assert_eq 3 "$(ls "$F/trash" | wc -l)" "two cleanups at once trash only what is over the budget ($(ls "$F/trash" | paste -sd' '))"
assert_eq 0 "$("$P" budget 0)" "back off"
echo "cleanup: ok"
