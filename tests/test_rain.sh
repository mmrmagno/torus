#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
srv=
trap '[[ -n $srv ]] && kill "$srv" 2> /dev/null; rm -rf "$F"' EXIT
export XDG_STATE_HOME=$F/state XDG_CACHE_HOME=$F/cache TZ=Europe/Zurich
NOW=1762843500
mkdir -p "$F/www/forecast"
echo '{"nearest_area":[{"latitude":"47.37","longitude":"8.54"}]}' > "$F/www/place"
mk() { python3 -c "import json,sys; n=int(sys.argv[1]); p=[float(x) for x in sys.argv[2:]]; print(json.dumps({'minutely_15': {'time': [n - n % 900 + 900 * i for i in range(len(p))], 'precipitation': p}}))" "$NOW" "$@" > "$F/www/forecast/index.html"; }
port=$((20000 + RANDOM % 20000))
python3 -m http.server -d "$F/www" -b 127.0.0.1 "$port" > /dev/null 2>&1 & srv=$!
export TORUS_RAIN_API=http://127.0.0.1:$port/forecast/ TORUS_RAIN_PLACE=http://127.0.0.1:$port/place
for _ in $(seq 50); do curl -sf "$TORUS_RAIN_PLACE" > /dev/null && break; sleep 0.1; done
R=$REPO/home/.local/bin/torus-rain

mk 0 1.2 0.4 0.8 0 0 0 0
out=$("$R" --now "$NOW")
assert_eq "true:Heavy rain in 15 min" "$(jq -r '"\(.due):\(.title)"' <<< "$out")" "rain coming in the morning window: $out"
out=$("$R" --now "$((NOW + 60))")
assert_eq "false" "$(jq -r .due <<< "$out")" "told once per window"
rm -rf "$F/state"
mk 0.5 0.5 0.5 0 0 0 0 0
assert_eq "false" "$("$R" --now "$NOW" | jq -r .due)" "already raining: no heads-up"
mk 0 0 0 0 0 0 0 0
assert_eq "false" "$("$R" --now "$NOW" | jq -r .due)" "dry hour"
mk 0 0.3 0 0 0 0 0 0
assert_eq "false" "$("$R" --now 1762891200 | jq -r .due)" "outside the windows nothing is fetched"
assert_eq "false" "$("$R" --now 1763193600 | jq -r .due)" "weekends are quiet"
echo "rain: ok"
