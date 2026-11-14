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
assert_eq 0 "$("$P" budget 0)" "back off"
echo "cleanup: ok"
