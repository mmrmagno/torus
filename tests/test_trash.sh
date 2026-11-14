#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$REPO/home/.config/quickshell/torus"
bad=$(grep -rnE '"rm"|\brm -r?f\b' --include='*.qml' . | grep -vE '^\./services/Clip\.qml|^\./lock/Lock\.qml' || true)
[[ -z $bad ]] || fail "rm on user files (use Store.trash): $bad"
grep -q '"torus-trash", "put"' Store.qml || fail "Store.trash does not go through torus-trash"
grep -q '"gio", "trash", "--", path' "$REPO/home/.local/bin/torus-trash" || fail "torus-trash does not use gio trash"
grep -q 'Store.trash(p)' capture/CaptureStudio.qml || fail "capture studio does not trash"
grep -q 'Store.trash(p)' services/Island.qml || fail "island Delete does not trash"
grep -q '"torus-launch", "satty"' services/Island.qml || fail "island Edit starts satty without torus-launch"
n=$(grep -c 'Store.sound("delete")\|Store.trash(' services/Island.qml)
assert_eq 1 "$n" "island: one delete path"
grep -q 'cliphist store < ' services/Clip.qml || fail "unpinning gives the content back to the history"
grep -qF 'shift && rm -f -- ' services/Clip.qml || fail "deleting pins stays a real delete"
echo "trash: ok"
