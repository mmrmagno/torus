#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$REPO/home/.config/quickshell/torus/island/DynamicIsland.qml
win=$(grep -m1 -oP '^    implicitWidth: \K[0-9]+' "$F")
widest=$(sed -n '/readonly property int pillWidth: {/,/^    }/p' "$F" | grep -oP 'return \K[0-9]+' | sort -n | tail -n 1)
[[ -n $win && -n $widest ]] || fail "could not read the widths"
((widest + 20 <= win)) || fail "the island window ($win px) is narrower than its widest pill ($widest px) plus room for the bounce"
echo "island width: ok"
