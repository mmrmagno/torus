#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin"
export PATH=$F/bin:$PATH STUB_LOG=$F/calls
printf '#!/usr/bin/env bash\necho "slurp $*" >> "$STUB_LOG"\n[[ -n ${STUB_CANCEL:-} ]] && exit 1\necho "640 480 10 20"\n' > "$F/bin/slurp"
printf '#!/usr/bin/env bash\necho "wl-copy $(cat)" >> "$STUB_LOG"\n' > "$F/bin/wl-copy"
printf '#!/usr/bin/env bash\necho "qs $*" >> "$STUB_LOG"\n' > "$F/bin/qs"
chmod +x "$F/bin/"*
printf '#!/usr/bin/env bash\necho "hyprctl $*" >> "$STUB_LOG"\necho "[{\\"name\\":\\"DP-1\\",\\"focused\\":true}]"\n' > "$F/bin/hyprctl"
printf '#!/usr/bin/env bash\necho "grim $*" >> "$STUB_LOG"\n[[ -n ${STUB_NOSHELL:-} ]] && exit 1\n: > "${@: -1}"\n' > "$F/bin/grim"
chmod +x "$F/bin/"*
T=$REPO/home/.local/bin/torus-ruler
export XDG_RUNTIME_DIR=$F
"$T"
grep -qE "grim -o DP-1 $F/torus-ruler-[0-9]+\.png" "$STUB_LOG" || fail "freezes the focused screen: $(cat "$STUB_LOG")"
grep -qE "qs -c torus ipc call torus rulerShow $F/torus-ruler-[0-9]+\.png" "$STUB_LOG" || fail "opens the ruler overlay"
first=$(ls "$F"/torus-ruler-*.png)
"$T"
assert_eq 1 "$(ls "$F"/torus-ruler-*.png | wc -l)" "one frozen frame at a time"
[[ $(ls "$F"/torus-ruler-*.png) != "$first" ]] || fail "each run freezes a new file, or the overlay shows the first frame forever"
(unset XDG_RUNTIME_DIR; assert_fails "$T")
[[ ! -e /tmp/torus-ruler.png ]] || fail "never a world-readable screenshot in /tmp"
grep -q slurp "$STUB_LOG" && fail "no slurp when the shell answers"
: > "$STUB_LOG"
export STUB_NOSHELL=1

assert_eq 640x480 "$("$T")" "size printed"
grep -q '^wl-copy 640x480$' "$STUB_LOG" || fail "size copied"
grep -q 'islandFlash osd 640x480  ·  at 10,20  ·  copied' "$STUB_LOG" || fail "island shows it"
: > "$STUB_LOG"
STUB_CANCEL=1 "$T"
grep -q wl-copy "$STUB_LOG" && fail "Escape copies nothing"
true
