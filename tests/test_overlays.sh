#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$REPO/home/.config/quickshell/torus"
for f in components/SettingsSheet games/GameSettings games/ClipCutter components/QuickLook; do
  awk '/^    MouseArea \{/ {m=1; a=0; z=0; next} m && /^    \}/ {if (a && z) ok=1; m=0} m && /acceptedButtons: Qt.AllButtons/ {a=1} m && /z: -1/ {z=1} END {exit !ok}' "$f.qml" \
    || fail "$f.qml: an overlay must swallow clicks, or they reach the game card or clip under it"
done
grep -q 'TapHandler { onTapped: sheet.closed() }' components/SettingsSheet.qml && fail "SettingsSheet close must be a MouseArea (a passive tap let the cog below reopen it)"
awk '/Stop instant replay/ {s=NR} /icon: "󰒓"/ {c=NR} END {exit !(s && c > s)}' capture/CaptureStudio.qml || fail "capture studio cog must be the last button"
guard() { grep -A1 "$2" "$1.qml" | grep -q "enabled: $3" || fail "$1.qml: what a sheet covers must be off ($2), Qt hands a click on a sheet's row to every TapHandler under it"; }
guard games/GameHub 'visible: root.view === "games"$' '!root.covered'
guard games/GameHub '                visible: root.view === "clips"$' '!root.covered'
guard games/ClipLibrary '^    ColumnLayout {' 'lib.look === ""'
guard capture/CaptureStudio 'id: flick$' '!root.setting && root.look === ""'
guard network/NetPanel 'id: scroller$' 'Wifi.qrSsid === ""'
guard palette/CommandPanel 'id: list$' 'root.lookPath === ""'
guard palette/CommandPanel 'id: scopeBar$' 'root.lookPath === ""'
guard music/MusicPanel 'id: np$' '!root.covered'
(($(grep -c 'enabled: !root.covered' music/MusicPanel.qml) == 5)) || fail "MusicPanel: all five areas under its sheet and menu must be off"
echo "overlays: ok"
