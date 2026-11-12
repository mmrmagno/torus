#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
command -v ffmpeg > /dev/null && python3 -c 'import numpy' 2> /dev/null || { echo "skip: ffmpeg or numpy missing"; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
M="$REPO/vm/motion.py"
echo "0x1" > "$tmp/before"
printf '1.0 {"V": {"levels": {"3": [{"address": "0x9", "namespace": "torus-panel", "x": 40, "y": 20, "w": 240, "h": 200}]}}}\n' > "$tmp/layers"

clip() {
  python3 -c '
import sys, numpy as np
kind = sys.argv[1]
for i in range(144):
    f = np.full((240, 320, 3), 32, np.uint8)
    t = i / 60
    if 0.5 <= t < 1.7:
        h = min(150, int((t - 0.5) * 600)) if kind == "smooth" else (min(100, int((t - 0.5) * 600)) if t < 1.1 else 150)
        f[30:30 + h, 60:260] = 192
    sys.stdout.buffer.write(f.tobytes())
' "$1" | ffmpeg -v error -y -f rawvideo -pix_fmt rgb24 -s 320x240 -r 60 -i - -c:v libx264rgb -qp 0 -preset ultrafast "$tmp/$1.mkv"
}
clip smooth
clip snap

s=$(python3 "$M" "$tmp/smooth.mkv" "$tmp/layers" "$tmp/before" 320 240)
j=$(python3 "$M" "$tmp/snap.mkv" "$tmp/layers" "$tmp/before" 320 240)
assert_eq 0 "$(jq -r .jumps <<<"$s")" "smooth growth has no jumps"
assert_eq true "$(jq -r '.jumps > 0' <<<"$j")" "a snap is reported as a jump"
assert_eq 0 "$(jq -r .resizes <<<"$s")" "one geometry is no resize"
assert_eq true "$(jq -r '.open_ms >= 200 and .open_ms <= 300' <<<"$s")" "open time measured from the frames [$(jq -r .open_ms <<<"$s")]"

printf '1.1 {"V": {"levels": {"3": [{"address": "0x9", "namespace": "torus-panel", "x": 40, "y": 20, "w": 240, "h": 210}]}}}\n' >> "$tmp/layers"
r=$(python3 "$M" "$tmp/smooth.mkv" "$tmp/layers" "$tmp/before" 320 240)
assert_eq 1 "$(jq -r .resizes <<<"$r")" "layer size change counted as a resize"
echo "motion: ok"
