#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/run"
export XDG_RUNTIME_DIR=$F/run PATH=$F/bin:$PATH LOG=$F/log
cat > "$F/bin/hyprctl" <<'S'
#!/usr/bin/env bash
echo "hyprctl $*" >> "$LOG"
[[ $1 == monitors ]] && echo '[{"name":"eDP-1","width":2944,"height":1840,"refreshRate":90.0,"x":0,"y":0,"scale":1.33,"transform":0,"availableModes":["2944x1840@90.00Hz","2944x1840@60.00Hz","1920x1200@60.00Hz"]},{"name":"DP-2","width":2560,"height":1440,"refreshRate":144.0,"x":2213,"y":0,"scale":1,"transform":0,"availableModes":["2560x1440@144.00Hz","2560x1440@60.00Hz"]}]'
exit 0
S
chmod +x "$F/bin/hyprctl"
D=$F/repo/home/.local/bin; mkdir -p "$D"
cp "$REPO/home/.local/bin/torus-calm" "$D/"
printf '#!/bin/sh\necho reload >> "$LOG"\n' > "$D/torus-reload"; chmod +x "$D/torus-reload"

assert_eq off "$("$D/torus-calm" status)" "off at start"
"$D/torus-calm" off > /dev/null
[[ ! -s $LOG ]] || fail "off without the marker must not reload: $(cat "$LOG")"
"$D/torus-calm" on > /dev/null
assert_eq on "$("$D/torus-calm" status)" "marker set"
grep -q "hyprctl eval torus_calm_apply()" "$LOG" || fail "applies the calm config"
grep -q 'output = "eDP-1", mode = "2944x1840@60.00", position = "0x0", scale = 1.33, transform = 0' "$LOG" || fail "laptop panel goes to 60 Hz: $(cat "$LOG")"
grep -q 'output = "DP-2"' "$LOG" && fail "external screens keep their rate"
"$D/torus-calm" off > /dev/null
grep -q reload "$LOG" || fail "off reloads the config"
assert_eq off "$("$D/torus-calm" status)" "marker cleared"
grep -q 'dofile(dir .. "calm.lua")' "$REPO/home/.config/hypr/hyprland.lua" || fail "hyprland loads calm.lua"
echo "calm: ok"
