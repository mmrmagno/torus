#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/run"
export PATH=$F/bin:$PATH XDG_RUNTIME_DIR=$F/run XDG_PICTURES_DIR=$F/Pictures STUB_LOG=$F/calls FX=$REPO/tests/fixtures/shot
export CLIENTS=$FX/clients.json
cat > "$F/bin/hyprctl" <<'S'
#!/usr/bin/env bash
case "$*" in
  "monitors -j") cat "$FX/monitors.json" ;;
  "clients -j") cat "$CLIENTS" ;;
  "layers -j") echo '{}' ;;
esac
S
cat > "$F/bin/slurp" <<'S'
#!/usr/bin/env bash
echo "slurp $*" >> "$STUB_LOG"
cat > "$STUB_LOG.boxes"
echo "10,20 800x600"
S
printf '#!/bin/sh\necho "grim $*" >> "$STUB_LOG"\nfor a; do out=$a; done\necho png > "$out"\n' > "$F/bin/grim"
printf '#!/bin/sh\necho "hyprpicker $*" >> "$STUB_LOG"\n' > "$F/bin/hyprpicker"
printf '#!/bin/sh\ncat > /dev/null\n' > "$F/bin/wl-copy"
printf '#!/bin/sh\nexit 0\n' > "$F/bin/qs"
printf '#!/bin/sh\nexit 0\n' > "$F/bin/torus-sound"
printf '#!/bin/sh\nexit 0\n' > "$F/bin/satty"
chmod +x "$F/bin/"*
mkdir -p "$F/sh"
cp "$REPO/home/.local/bin/torus-shot" "$F/sh/"
cp "$F/bin/torus-sound" "$F/sh/"

"$F/sh/torus-shot" s
want='10,20 800x600 0xa1
3000,100 712x800 0xa2
2600,1200 500x400 0xa3'
assert_eq "$want" "$(cat "$STUB_LOG.boxes")" "boxes: windows on the visible workspaces, clipped to their screen"
grep -q '^grim -g 10,20 800x600 ' "$STUB_LOG" || fail "s: grim takes the clicked window"

: > "$STUB_LOG.boxes"
"$F/sh/torus-shot" sf
assert_eq "$want" "$(cat "$STUB_LOG.boxes")" "sf: frozen mode gets the same boxes"

jq '. + [{"address":"0xf1","mapped":true,"hidden":false,"at":[0,0],"size":[2560,1440],"workspace":{"id":1},"monitor":0,"class":"cs2","fullscreen":2}]' "$FX/clients.json" > "$F/full.json"
CLIENTS=$F/full.json "$F/sh/torus-shot" s
assert_eq '3000,100 712x800 0xa2
2600,1200 500x400 0xa3
0,0 2560x1440 0xf1' "$(cat "$STUB_LOG.boxes")" "a fullscreen window hides the windows behind it"

printf '[]' > "$F/none.json"
CLIENTS=$F/none.json "$F/sh/torus-shot" s
assert_eq "" "$(cat "$STUB_LOG.boxes")" "no windows: plain area mode"
printf '#!/bin/sh\nexit 1\n' > "$F/bin/hyprctl"
"$F/sh/torus-shot" s
assert_eq "" "$(cat "$STUB_LOG.boxes")" "hyprctl failing: plain area mode"
echo "shotwindow: ok"
