#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

command -v magick > /dev/null || { echo "skip: no magick"; exit 0; }
F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
T=$REPO/home/.local/bin/torus-wallcolor
mk() { magick -size 120x80 "xc:$1" -fill "$2" -draw 'rectangle 10,10 100,70' "$F/$3.png"; }
mk '#1a1020' '#9b59d0' purple
mk '#0d1a10' '#3fbf5a' green
mk '#101a26' '#e09040' orange
mk '#101010' '#2259e8' blue
assert_eq mauve "$("$T" "$F/purple.png" "$REPO/theme/mocha.json")" "purple leaves pick mauve"
assert_eq green "$("$T" "$F/green.png" "$REPO/theme/mocha.json")" "green picks green"
assert_eq peach "$("$T" "$F/orange.png" "$REPO/theme/mocha.json")" "orange picks peach"
assert_eq blue "$("$T" "$F/blue.png" "$REPO/theme/latte.json")" "works against the latte palette too"
rc=0; "$T" "$F/missing.png" "$REPO/theme/mocha.json" > /dev/null 2>&1 || rc=$?
assert_eq 1 "$rc" "unreadable picture fails quietly"
magick -size 200x120 radial-gradient:'#b86ee0'-'#140a20' -depth 16 "$F/deep.png"
assert_eq mauve "$("$T" "$F/deep.png" "$REPO/theme/mocha.json")" "16-bit pictures parse too"
true
