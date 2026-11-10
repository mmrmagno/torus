#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/cfg"
export STUB_LOG=$F/calls PATH=$F/bin:$PATH XDG_RUNTIME_DIR=$F TORUS_RELOAD_SETTLE=0 CFG=$F/cfg
cat > "$F/bin/hyprctl" <<'S'
#!/usr/bin/env bash
echo "hyprctl $*" >> "$STUB_LOG"
[[ $1 == configerrors ]] && grep -l BROKEN "$CFG"/* 2> /dev/null | sed 's/^/error in /'
if [[ $1 == eval ]]; then
  f=${2#dofile(\'}; f=${f%\')}
  grep -q LUAERR "$f" && echo "error: $f:1: unknown field 'nonsense'" || echo ok
fi
exit 0
S
printf '#!/usr/bin/env bash\necho "notify-send $*" >> "$STUB_LOG"\n' > "$F/bin/notify-send"
chmod +x "$F/bin/"*
R=$REPO/home/.local/bin/torus-reload

echo good > "$CFG/rules.lua"
echo better | "$R" write "$CFG/rules.lua" || fail "a good change is kept"
assert_eq better "$(cat "$CFG/rules.lua")" "good change written"
grep -q '^hyprctl reload' "$STUB_LOG" || fail "reloads hyprland"

: > "$STUB_LOG"
echo BROKEN | "$R" write "$CFG/rules.lua" 2> /dev/null && fail "a broken change must fail"
assert_eq better "$(cat "$CFG/rules.lua")" "broken change undone"
(( $(grep -c '^hyprctl reload' "$STUB_LOG") == 2 )) || fail "reloads again after undoing"
grep -q 'notify-send .*change undone error in' "$STUB_LOG" || fail "tells about the error: $(cat "$STUB_LOG")"

echo BROKEN | "$R" write "$CFG/new.lua" 2> /dev/null && fail "a broken new file must fail"
[[ ! -e $CFG/new.lua ]] || fail "a broken new file is removed"
ls "$F" | grep -q torus-reload && fail "no temp files left"

echo BROKEN > "$CFG/hand.lua"
: > "$STUB_LOG"
"$R" 2> /dev/null && fail "plain reload reports errors"
grep -q 'notify-send .*Hyprland config error' "$STUB_LOG" || fail "plain reload notifies"
assert_eq BROKEN "$(cat "$CFG/hand.lua")" "hand edits are never touched"
rm "$CFG/hand.lua"
"$R" || fail "clean reload succeeds"

: > "$STUB_LOG"
echo good > "$CFG/rules.lua"
echo LUAERR | "$R" write "$CFG/rules.lua" 2> /dev/null && fail "a lua file that does not load must fail"
assert_eq good "$(cat "$CFG/rules.lua")" "a bad lua file never replaces the old one"
grep -q '^hyprctl reload' "$STUB_LOG" && fail "nothing to reload when the change was refused"
grep -q "notify-send .*not applied.*unknown field" "$STUB_LOG" || fail "tells what is wrong: $(cat "$STUB_LOG")"
[[ ! -e $CFG/rules.lua.torus-new ]] || fail "no half written file left"
