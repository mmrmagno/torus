#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO/home/.config/quickshell/torus"
bad=$(python3 - <<'PY'
import glob, re
pic = re.compile(r'^\s*(Image|AnimatedImage|ScreencopyView|VideoOutput) \{')
for f in sorted(glob.glob('**/*.qml', recursive=True)):
    lines = open(f).read().split('\n')
    for i, l in enumerate(lines):
        if l.strip() != 'clip: true':
            continue
        ind = len(l) - len(l.lstrip())
        start = i
        while start > 0 and not (len(lines[start]) - len(lines[start].lstrip()) == ind - 4 and lines[start].rstrip().endswith('{')):
            start -= 1
        end = i
        while end < len(lines) - 1 and not (lines[end].strip() == '}' and len(lines[end]) - len(lines[end].lstrip()) == ind - 4):
            end += 1
        block = lines[start:end + 1]
        rounded = any(len(b) - len(b.lstrip()) == ind and re.match(r'\s*radius: (?!0\b)', b) for b in block)
        direct = [b for b in block if pic.match(b)]
        if rounded and direct and 'ClippingRectangle' not in ''.join(block):
            print(f'{f}:{i + 1}')
PY
)
[[ -z $bad ]] || fail "a picture sits in a rounded shape with clip: true (use a ClippingRectangle): $bad"
for f in overview/Overview switcher/AltTab clip/ClipPanel studio/ThemeStudio notifications/MediaCard widgets/Widgets bar/modules/Workspaces components/CaptureTile games/GameHub; do
  grep -q 'ClippingRectangle {' "$f.qml" || fail "$f.qml shows pictures in rounded shapes without a ClippingRectangle"
done
echo "pictures: ok"
