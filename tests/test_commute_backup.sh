#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
srv=
trap '[[ -n $srv ]] && kill "$srv" 2> /dev/null; rm -rf "$F"' EXIT
export XDG_CONFIG_HOME=$F/config XDG_CACHE_HOME=$F/cache XDG_STATE_HOME=$F/state TZ=Europe/Zurich
port=$((20000 + RANDOM % 20000))
python3 -I "$REPO/tests/fixtures/ojp/server.py" "$port" & srv=$!
mkdir -p "$F/bin"
C=$(patched "$REPO/home/.local/bin/torus-commute" "$F/bin" https://transport.opendata.ch/v1 http://127.0.0.1:1 https://api.opentransportdata.swiss/ojp20 "http://127.0.0.1:$port")
for _ in $(seq 50); do curl -s -o /dev/null "http://127.0.0.1:$port" && break; sleep 0.1; done
mkdir -p "$XDG_CONFIG_HOME/torus"
echo '{"home": "Home street 1", "work": "Work road 2"}' > "$XDG_CONFIG_HOME/torus/commute.json"
NOW=1762840800

out=$("$C" fetch --to work --now "$NOW" || true)
assert_eq "False" "$(jq -r '.ok | if . then "True" else "False" end' <<< "$out")" "no key: the outage is reported as before"

printf 'test-key\n' > "$XDG_CONFIG_HOME/torus/ojp.key"
chmod 644 "$XDG_CONFIG_HOME/torus/ojp.key"
out=$("$C" fetch --to work --now "$NOW" || true)
assert_eq "false" "$(jq -r .ok <<< "$out")" "a key readable by others is ignored"

chmod 600 "$XDG_CONFIG_HOME/torus/ojp.key"
out=$("$C" fetch --to work --now "$NOW")
assert_eq "true:true:backup timetable" "$(jq -r '"\(.ok):\(.backup):\(.message)"' <<< "$out")" "backup timetable used"
assert_eq "IC 8:7:2:47" "$(jq -r '.connections[0] | "\(.lines[0]):\(.platform):\(.delay):\(.minutes)"' <<< "$out")" "trip parsed: line, platform, delay, minutes"
assert_eq "walk:ride" "$(jq -r '.connections[0].legs | map(.kind) | join(":")' <<< "$out")" "legs"
out=$("$C" fetch --to work --now "$((NOW + 10))")
assert_eq "true" "$(jq -r .backup <<< "$out")" "cached backup result still says backup"
echo "commute backup: ok"
