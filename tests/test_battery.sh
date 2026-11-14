#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
B=$REPO/home/.local/bin/torus-battery
export TORUS_POWER_SUPPLY=$F/ps TORUS_IDEAPAD=$F/ideapad
mkdir -p "$F/ps"
assert_eq '{"present":false}' "$("$B")" "desktop: no battery"

mkdir -p "$F/ps/BAT0" "$F/ideapad/VPC2004:00"
echo 57000000 > "$F/ps/BAT0/energy_full"; echo 71000000 > "$F/ps/BAT0/energy_full_design"; echo 312 > "$F/ps/BAT0/cycle_count"
echo 0 > "$F/ideapad/VPC2004:00/conservation_mode"
assert_eq "80:312:conservation:false:true" "$("$B" | jq -r '"\(.health):\(.cycles):\(.limit):\(.on):\(.writable)"')" "health from energy, Yoga conservation mode"
assert_eq true "$("$B" limit on | jq -r .on)" "limit on"
assert_eq 1 "$(cat "$F/ideapad/VPC2004:00/conservation_mode")" "conservation mode written"
"$B" limit off > /dev/null
assert_eq 0 "$(cat "$F/ideapad/VPC2004:00/conservation_mode")" "and back"

echo 100 > "$F/ps/BAT0/charge_control_end_threshold"
assert_eq "threshold:false" "$("$B" | jq -r '"\(.limit):\(.on)"')" "a real threshold wins"
"$B" limit on > /dev/null
assert_eq 80 "$(cat "$F/ps/BAT0/charge_control_end_threshold")" "80 %"
chmod a-w "$F/ps/BAT0/charge_control_end_threshold"
if [[ $EUID -ne 0 ]]; then
  "$B" limit off 2> "$F/err" && fail "not writable must fail"
  grep -q 'install.sh --system' "$F/err" || fail "says how to allow it"
fi
grep -q 'chgrp wheel' "$REPO/system/etc/udev/rules.d/90-torus-charge-limit.rules" || fail "udev rule ships with --system"
calls=$(grep -rnE '"torus-battery", *"limit"|torus-battery limit' "$REPO/home/.config/quickshell" "$REPO/install.sh" "$REPO/home/.local/bin" | grep -v '^.*/torus-battery:' || true)
[[ $(wc -l <<< "$calls") == 1 ]] || fail "one place switches the limit: $calls"
grep -q 'onToggled' <<< "$(grep -n -B3 '"torus-battery", *"limit"' "$REPO/home/.config/quickshell/torus/dashboard/Dashboard.qml")" || fail "only the switch the user flips turns the limit on: $calls"
echo "battery: ok"
