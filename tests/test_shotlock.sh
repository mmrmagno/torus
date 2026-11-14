#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'pkill -f "sleep 4[.]5" 2> /dev/null; rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/run"
export PATH=$F/bin:$PATH XDG_RUNTIME_DIR=$F/run XDG_PICTURES_DIR=$F/Pictures
printf '#!/bin/sh\necho "0,0 10x10"\n' > "$F/bin/slurp"
printf '#!/bin/sh\nfor a; do out=$a; done\necho png > "$out"\n' > "$F/bin/grim"
printf '#!/bin/sh\ncat > /dev/null\nsleep 4.5 &\nexit 0\n' > "$F/bin/wl-copy"
printf '#!/bin/sh\nexit 0\n' > "$F/bin/qs"
printf '#!/bin/sh\nexit 0\n' > "$F/bin/torus-sound"
chmod +x "$F/bin/"*
mkdir -p "$F/sh"
cp "$REPO/home/.local/bin/torus-shot" "$F/sh/"
cp "$F/bin/torus-sound" "$F/sh/"

"$F/sh/torus-shot" s
sleep 1.1
"$F/sh/torus-shot" s
assert_eq 2 "$(ls "$F/Pictures/Screenshots" | wc -l)" "a second area screenshot works while the clipboard still holds the first"
echo "shotlock: ok"
