#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/proc/100" "$F/proc/101" "$F/proc/200" "$F/proc/201" "$F/apps/applications" "$F/state"
export STUB_LOG=$F/calls TORUS_PROC=$F/proc XDG_DATA_DIRS=$F/apps XDG_DATA_HOME=$F/nohome XDG_STATE_HOME=$F/state
ln -s /home/me/dev/torus "$F/proc/101/cwd"
ln -s /home/me/music "$F/proc/201/cwd"
mkdir -p "$F/proc/100/task/100" "$F/proc/200/task/200"
mkdir -p "$F/proc/99"; echo kitten > "$F/proc/99/comm"; ln -s /home/me "$F/proc/99/cwd"; echo zsh > "$F/proc/101/comm"; echo zsh > "$F/proc/201/comm"
echo "99 101" > "$F/proc/100/task/100/children"
echo 201 > "$F/proc/200/task/200/children"
cat > "$F/bin/hyprctl" <<'S'
#!/usr/bin/env bash
echo "hyprctl $*" >> "$STUB_LOG"
if [[ $1 == clients ]]; then cat <<'J'
[{"class":"kitty","pid":100,"mapped":true,"workspace":{"id":2}},
 {"class":"kitty","pid":200,"mapped":true,"workspace":{"id":3}},
 {"class":"zen","pid":300,"mapped":true,"workspace":{"id":1}},
 {"class":"zen","pid":300,"mapped":true,"workspace":{"id":4}},
 {"class":"cs2","pid":400,"mapped":true,"workspace":{"id":5}},
 {"class":"steam_app_730","pid":401,"mapped":true,"workspace":{"id":5}},
 {"class":"kitty","pid":500,"mapped":true,"workspace":{"id":-98}}]
J
fi
S
printf '[Desktop Entry]\nName=Zen Browser\nExec=zen-browser %%u\nStartupWMClass=zen\n' > "$F/apps/applications/zen.desktop"
chmod +x "$F/bin"/*
export PATH=$F/bin:$PATH
T=$REPO/home/.local/bin/torus-session

"$T" save
S=$F/state/torus/session.tsv
assert_eq "$(printf 'kitty\t2\t/home/me/dev/torus\nkitty\t3\t/home/me/music\nzen\t1\t')" "$(cat "$S")" "save: windows, workspaces, kitty folders; no games, no special workspaces"

: > "$STUB_LOG"
"$T" restore
grep -qF 'hl.exec_cmd("[workspace 2 silent] kitty --directory /home/me/dev/torus")' "$STUB_LOG" || fail "kitty restored in its folder: $(cat "$STUB_LOG")"
grep -q '\[workspace 3 silent\] kitty --directory /home/me/music' "$STUB_LOG" || fail "second kitty"
grep -q '\[workspace 1 silent\] gtk-launch zen' "$STUB_LOG" || fail "zen via its desktop entry"
assert_eq 1 "$(grep -c 'gtk-launch zen' "$STUB_LOG")" "zen launched once"
assert_absent "$S"

: > "$STUB_LOG"
"$T" restore
grep -q 'exec_cmd' "$STUB_LOG" && fail "restore runs once"

"$T" save
echo off > "$F/state/torus/session-restore"
: > "$STUB_LOG"
"$T" restore
grep -q 'exec_cmd' "$STUB_LOG" && fail "restore off"
true
