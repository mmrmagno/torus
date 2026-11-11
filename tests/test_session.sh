#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/proc/100" "$F/proc/101" "$F/proc/200" "$F/proc/201" "$F/apps/applications" "$F/state"
export HYPRLAND_INSTANCE_SIGNATURE=login1 STUB_LOG=$F/calls TORUS_PROC=$F/proc XDG_DATA_DIRS=$F/apps XDG_DATA_HOME=$F/nohome XDG_STATE_HOME=$F/state
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
cp "$F/bin/hyprctl" "$F/hyprctl.real"
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
[[ -s $S ]] || fail "restore keeps the saved session, so a reboot before the next save loses nothing"

: > "$STUB_LOG"
"$T" restore
grep -q 'exec_cmd' "$STUB_LOG" && fail "restore runs once per login"

: > "$STUB_LOG"
: > "$STUB_LOG"
HYPRLAND_INSTANCE_SIGNATURE=race "$T" restore & HYPRLAND_INSTANCE_SIGNATURE=race "$T" restore & HYPRLAND_INSTANCE_SIGNATURE=race "$T" restore; wait
assert_eq 1 "$(grep -c 'kitty --directory /home/me/music' "$STUB_LOG")" "parallel restores at login reopen once"
HYPRLAND_INSTANCE_SIGNATURE=login2 "$T" restore
grep -q 'kitty --directory /home/me/music' "$STUB_LOG" || fail "next login restores again"

cp "$S" "$F/good"
cat > "$F/bin/hyprctl" <<'S'
#!/usr/bin/env bash
exit 1
S
"$T" save && fail "save fails when Hyprland is gone"
cmp -s "$S" "$F/good" || fail "failed save keeps the last session"
assert_eq '[]' "$("$T" preview)" "preview empty when Hyprland is gone"
cp "$F/hyprctl.real" "$F/bin/hyprctl"; chmod +x "$F/bin/hyprctl"

"$T" save
echo off > "$F/state/torus/session-restore"
: > "$STUB_LOG"
"$T" restore
grep -q 'exec_cmd' "$STUB_LOG" && fail "restore off"

echo on > "$F/state/torus/session-restore"
P=$("$T" preview)
assert_eq keep "$(jq -r '.[] | select(.class == "zen") | .verdict' <<<"$P")" "preview: zen will come back"
assert_eq never "$(jq -r '.[] | select(.class == "cs2") | .verdict' <<<"$P")" "preview: games never come back"
assert_eq /home/me/dev/torus "$(jq -r '[.[] | select(.class == "kitty")][0].dir' <<<"$P")" "preview: kitty folder shown"
assert_eq 0 "$(jq '[.[] | select(.ws < 0)] | length' <<<"$P")" "preview: special workspaces left out"

"$T" skip zen
assert_eq skipped "$("$T" preview | jq -r '.[] | select(.class == "zen") | .verdict')" "skip: zen marked skipped"
"$T" save
grep -q '^zen' "$S" && fail "skip: zen not saved"
assert_eq '["zen"]' "$("$T" status | jq -c .skipped)" "status lists skipped apps"
"$T" unskip zen
assert_eq keep "$("$T" preview | jq -r '.[] | select(.class == "zen") | .verdict')" "unskip: zen back"

"$T" off
assert_eq false "$("$T" status | jq .on)" "status: off"
"$T" on
assert_eq true "$("$T" status | jq .on)" "status: on"
"$T" save
assert_eq 3 "$("$T" status | jq .saved)" "status: saved count"
"$T" clear
assert_eq 0 "$("$T" status | jq .saved)" "clear empties the saved session"
true
