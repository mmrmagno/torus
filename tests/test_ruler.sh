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
T=$REPO/home/.local/bin/torus-ruler

assert_eq 640x480 "$("$T")" "size printed"
grep -q '^wl-copy 640x480$' "$STUB_LOG" || fail "size copied"
grep -q 'islandFlash osd 640x480  ·  at 10,20  ·  copied' "$STUB_LOG" || fail "island shows it"
: > "$STUB_LOG"
STUB_CANCEL=1 "$T"
grep -q wl-copy "$STUB_LOG" && fail "Escape copies nothing"
true
