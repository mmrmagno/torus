#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin"
export HOME=$F/home STUB_LOG=$F/calls XDG_STATE_HOME=$F/state XDG_CACHE_HOME=$F/cache
printf '#!/usr/bin/env bash\necho "${PICK-#CBA6F7}"\n' > "$F/bin/hyprpicker"
printf '#!/usr/bin/env bash\necho "wl-copy $(cat)" >> "$STUB_LOG"\n' > "$F/bin/wl-copy"
printf '#!/usr/bin/env bash\nprintf "notify %%s\\n" "$*" >> "$STUB_LOG"\n' > "$F/bin/notify-send"
chmod +x "$F/bin"/*
export PATH=$F/bin:$PATH
T=$REPO/home/.local/bin/torus-pick

"$T"
grep -qx 'wl-copy #cba6f7' "$F/calls" || fail "copies lowercase hex: $(cat "$F/calls")"
grep -q 'notify .*#cba6f7 copied rgb(203, 166, 247)  ·  hsl(267, 84%, 81%)' "$F/calls" || fail "notifies rgb and hsl: $(cat "$F/calls")"
grep -q "fill='#cba6f7'" "$F/cache/torus/swatches/pick-cba6f7.svg" || fail "swatch icon written"
PICK='#89B4FA' "$T"
"$T"
assert_eq "$(printf '#cba6f7\n#89b4fa')" "$(cat "$F/state/torus/colors")" "history newest first, no duplicates"
: > "$F/calls"
PICK='' "$T"
assert_eq "" "$(cat "$F/calls")" "cancelled pick does nothing"
true
