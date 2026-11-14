#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$REPO/home/.config/quickshell/torus"
for f in processes/ProcPanel overview/Overview switcher/AltTab notifications/Center network/NetPanel session/SessionPanel \
  spire/SpireHub updates/UpdatesPanel ocr/OcrPanel ai/AiPanel polkit/Polkit capture/CaptureStudio dashboard/Dashboard \
  cheatsheet/CheatSheet games/GameHub games/ClipLibrary games/GameSettings games/ClipCutter ruler/Ruler; do
  grep -qE '^\s*(KeyHints|HintPill) \{' "$f.qml" || fail "$f.qml has keys but no hint bar"
  grep -q 'import qs.components' "$f.qml" || fail "$f.qml does not import qs.components"
done
grep -q 'Tab sort' processes/ProcPanel.qml && fail "ProcPanel still has its text hint line"
echo "hints: ok"
