#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export HOME=$F/home XDG_CACHE_HOME=$F/home/.cache STUB_LOG=$F/calls
mkdir -p "$HOME" "$F/bin"
cat > "$F/bin/curl" <<'S'
#!/usr/bin/env bash
echo "curl $*" >> "$STUB_LOG"
[[ -n ${STUB_OFFLINE:-} ]] && exit 6
printf '{"syncedLyrics":"[00:01.00] first line\\n[00:04.50] second line"}'
S
chmod +x "$F/bin/curl"
export PATH=$F/bin:$PATH
L=$REPO/home/.local/bin/torus-lyrics

out=$("$L" "Artist" "Song" "Album" 123)
assert_contains <(echo "$out") "[00:04.50] second line"
grep -q 'artist_name=Artist' "$STUB_LOG" || fail "query has artist"
grep -q 'duration=123' "$STUB_LOG" || fail "query has duration"

: > "$STUB_LOG"
out2=$("$L" "Artist" "Song" "Album" 123)
assert_eq "$out" "$out2" "cached result"
[[ -s $STUB_LOG ]] && fail "second lookup must come from cache"

rc=0
STUB_OFFLINE=1 "$L" "Other" "Track" "" 10 > "$F/off" || rc=$?
assert_eq 0 "$rc" "offline lookup exits 0"
assert_eq 0 "$(wc -c < "$F/off")" "offline prints nothing"
