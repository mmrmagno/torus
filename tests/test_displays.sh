#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin"
export XDG_STATE_HOME=$F/state PATH=$F/bin:$PATH STUB_LOG=$F/calls
cat > "$F/bin/hyprctl" <<'S'
#!/usr/bin/env bash
echo "hyprctl $*" >> "$STUB_LOG"
[[ $1 == monitors ]] && cat "$STUB_MONS"
exit 0
S
printf '#!/usr/bin/env bash\necho "notify-send $*" >> "$STUB_LOG"\n' > "$F/bin/notify-send"
chmod +x "$F/bin/"*
T=$REPO/home/.local/bin/torus-displays
desk=$F/desk.json; lap=$F/lap.json
echo '[{"name":"eDP-1","description":"BOE 0x0BCA","width":2256,"height":1504,"refreshRate":59.999,"x":0,"y":1440,"scale":1.5,"transform":0,"disabled":false},{"name":"DP-3","description":"Dell U2723QE ABC","width":3840,"height":2160,"refreshRate":60.0,"x":0,"y":0,"scale":1.5,"transform":0,"disabled":false}]' > "$desk"
echo '[{"name":"eDP-1","description":"BOE 0x0BCA","width":2256,"height":1504,"refreshRate":59.999,"x":0,"y":0,"scale":1.5,"transform":0,"disabled":false}]' > "$lap"

STUB_MONS=$desk "$T" apply --hotplug > /dev/null
grep -q 'notify-send .*New set of screens' "$STUB_LOG" || fail "an unknown set says how to save it"
: > "$STUB_LOG"
STUB_MONS=$desk "$T" apply --hotplug > /dev/null
grep -q notify-send "$STUB_LOG" && fail "only once per set"
assert_eq "saved: BOE 0x0BCA + Dell U2723QE ABC" "$(STUB_MONS=$desk "$T" save)" "save keyed by the sorted descriptions"
STUB_MONS=$lap "$T" save > /dev/null
assert_eq 2 "$(jq 'keys | length' "$XDG_STATE_HOME/torus/displays.json")" "two sets remembered"
: > "$STUB_LOG"
assert_eq "applied: BOE 0x0BCA + Dell U2723QE ABC" "$(STUB_MONS=$desk "$T" apply)" "apply"
grep -qF 'hl.monitor({ output = "desc:Dell U2723QE ABC", mode = "3840x2160@60", position = "0x0", scale = 1.5, transform = 0 })' "$STUB_LOG" || fail "monitor rule by description: $(cat "$STUB_LOG")"
grep -qF 'output = "desc:BOE 0x0BCA", mode = "2256x1504@59.999", position = "0x1440"' "$STUB_LOG" || fail "panel below the external screen"
STUB_MONS=$lap "$T" forget > /dev/null
assert_eq 1 "$(jq 'keys | length' "$XDG_STATE_HOME/torus/displays.json")" "forget only this set"
assert_eq "unknown: BOE 0x0BCA" "$(STUB_MONS=$lap "$T" apply)" "a forgotten set is unknown again"

STUB_MONS=$lap "$T" save > /dev/null
out=$(STUB_MONS=$lap "$T" tsv)
grep -qx "BOE 0x0BCA	1	current" <<< "$out" || fail "tsv marks the current set: $out"
grep -qx "BOE 0x0BCA + Dell U2723QE ABC	2	" <<< "$out" || fail "tsv lists the other set: $out"
: > "$STUB_LOG"
STUB_MONS=$lap "$T" use "BOE 0x0BCA + Dell U2723QE ABC" > /dev/null
grep -q 'desc:Dell U2723QE ABC' "$STUB_LOG" || fail "use applies a named layout"
STUB_MONS=$lap "$T" drop "BOE 0x0BCA + Dell U2723QE ABC" > /dev/null
assert_eq 1 "$(jq 'keys | length' "$XDG_STATE_HOME/torus/displays.json")" "drop by name"
