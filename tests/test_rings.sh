#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$REPO/home/.config/quickshell/torus"
for f in dashboard/Dashboard network/NetPanel session/SessionPanel studio/ThemeStudio updates/UpdatesPanel spire/SpireHub capture/CaptureStudio; do
  awk '/Flickable \{/ {f=1} f && /^\s*x: 5$/ {x=1} f && /^\s*y: 5$/ {y=1} f && /width: parent.width - 10/ {w=1} END {exit !(x && y && w)}' "$f.qml" \
    || fail "$f.qml: scrolling content is not inset, a focus ring at the edge gets clipped"
done
for f in components/PanelButton components/Toggle components/Segmented components/ValueSlider components/VolumeSlider network/NetPanel dashboard/Calendar dashboard/CommuteCard; do
  grep -q 'FocusRing {' "$f.qml" || fail "$f.qml: focusable control without a focus ring"
done
echo "rings: ok"
