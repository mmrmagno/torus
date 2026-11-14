#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$REPO/home/.config/quickshell/torus"
for f in components/SettingsSheet games/GameSettings games/ClipCutter components/QuickLook; do
  awk '/^    MouseArea \{/ {m=1; a=0; z=0; next} m && /^    \}/ {if (a && z) ok=1; m=0} m && /acceptedButtons: Qt.AllButtons/ {a=1} m && /z: -1/ {z=1} END {exit !ok}' "$f.qml" \
    || fail "$f.qml: an overlay must swallow clicks, or they reach the game card or clip under it"
done
grep -q 'TapHandler { onTapped: sheet.closed() }' components/SettingsSheet.qml && fail "SettingsSheet close must be a MouseArea (a passive tap let the cog below reopen it)"
awk '/Stop instant replay/ {s=NR} /icon: "󰒓"/ {c=NR} END {exit !(s && c > s)}' capture/CaptureStudio.qml || fail "capture studio cog must be the last button"
echo "overlays: ok"
