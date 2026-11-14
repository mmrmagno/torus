#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export HOME=$F XDG_DATA_HOME=$F/share XDG_STATE_HOME=$F/state
command -v gio > /dev/null || { echo "trashcan: skipped (no gio)"; exit 0; }
T=$REPO/home/.local/bin/torus-trash
mkdir -p "$F/Videos/Clips/hades" "$F/other"
a=$F/Videos/Clips/hades/a.mp4; b=$F/Videos/Clips/hades/b.mp4; o=$F/other/doc.txt
head -c 2000 /dev/urandom > "$a"; head -c 3000 /dev/urandom > "$b"; echo mine > "$o"
gio trash "$o"

assert_eq 2 "$("$T" put "$a" "$b")" "two files trashed"
[[ ! -e $a && ! -e $b ]] || fail "put left the files"
st=$("$T" status)
assert_eq "2 5000 2" "$(jq -r '"\(.count) \(.bytes) \(.undo)"' <<< "$st")" "status counts only what torus trashed"
"$T" undo > /dev/null
[[ -f $a && -f $b ]] || fail "undo brings both back"
assert_eq "0 0 0" "$("$T" status | jq -r '"\(.count) \(.bytes) \(.undo)"')" "nothing held after undo"
assert_fails "$T" undo

"$T" put "$a" > /dev/null
echo newer > "$a"
assert_fails "$T" undo
assert_eq newer "$(cat "$a")" "undo never overwrites a file that took the old name"

"$T" put "$b" > /dev/null
assert_eq 2 "$("$T" empty)" "empty removes what torus trashed and is still there"
[[ -e $F/share/Trash/files/doc.txt ]] || fail "empty touched something torus did not trash"
assert_eq 0 "$("$T" status | jq -r .count)" "ledger cleared"
assert_eq 0 "$("$T" put "$F/nope" || true)" "a missing file is a no-op"
assert_fails "$T" frobnicate
c=$F/Videos/Clips/hades/c.mp4; echo mine > "$c"
"$T" put "$c" > /dev/null
gio trash --restore "trash:///c.mp4" 2> /dev/null || { mv "$F/share/Trash/files/c.mp4" "$c"; rm -f "$F/share/Trash/info/c.mp4.trashinfo"; }
mkdir -p "$F/Downloads"; echo theirs > "$F/Downloads/c.mp4"; gio trash "$F/Downloads/c.mp4"
[[ -e $F/share/Trash/files/c.mp4 ]] || fail "fixture: gio reused the name"
assert_eq 0 "$("$T" status | jq -r .count)" "a reused trash name from another app is not ours"
"$T" empty > /dev/null
[[ -e $F/share/Trash/files/c.mp4 ]] || fail "empty deleted another app's file that took our old trash name"
rm -f "$c"
assert_fails "$T" undo
[[ ! -e $c ]] || fail "undo restored another app's file to our old path"

d=$F/Videos/Clips/hades/d.mp4; e=$F/Videos/Clips/hades/e.mp4
echo d > "$d"; echo e > "$e"
"$T" put "$d" > /dev/null
"$T" undo "$e" > "$F/undo.out" &
sleep 0.4
"$T" put "$e" > /dev/null
wait $! || fail "an undo that started before its delete landed gave up: $(cat "$F/undo.out")"
[[ -f $e ]] || fail "undo brings back the file just deleted"
[[ ! -e $d ]] || fail "undo restored an older delete instead of the one it was asked for"
assert_fails timeout 5 "$T" undo "$F/Videos/Clips/hades/never.mp4"
echo "trashcan: ok"
