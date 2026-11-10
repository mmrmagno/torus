#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
srv=
trap '[[ -n $srv ]] && kill "$srv" 2> /dev/null; rm -rf "$F"' EXIT
export XDG_CONFIG_HOME=$F/config XDG_CACHE_HOME=$F/cache XDG_STATE_HOME=$F/state TZ=Europe/Zurich
C=$REPO/home/.local/bin/torus-commute
NOW=1794294000
port=$((20000 + RANDOM % 20000))
python3 -m http.server -d "$REPO/tests/fixtures/commute" -b 127.0.0.1 "$port" > /dev/null 2>&1 & srv=$!
export TORUS_COMMUTE_API=http://127.0.0.1:$port
for _ in $(seq 50); do curl -sf "$TORUS_COMMUTE_API/connections" > /dev/null && break; sleep 0.1; done

q() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

out=$("$C" fetch --now "$NOW" || true)
assert_eq False "$(q 'd["configured"]' <<< "$out")" "no config asks for addresses"

echo '{"home": "Home street 1", "work": "Work road 2", "extra": 1}' | "$C" save > /dev/null
assert_eq '{"home": "Home street 1", "work": "Work road 2"}' "$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' "$XDG_CONFIG_HOME/torus/commute.json")" "save keeps only home and work"
assert_eq 600 "$(stat -c %a "$XDG_CONFIG_HOME/torus/commute.json")" "config is private"

out=$("$C" fetch --now "$NOW")
assert_eq True "$(q 'd["toWork"]' <<< "$out")" "morning goes to work"
assert_eq "Home Work" "$(q 'd["fromLabel"], d["toLabel"]' <<< "$out" | tr -d "(),'")" "labels"
assert_eq "IC 1|IC 5|RE 2" "$(q '"|".join(c["lines"][0] for c in d["connections"])' <<< "$out")" "the S 3 that arrives after a later IC is dropped"
assert_eq "True" "$(q 'd["connections"][1].get("fastest")' <<< "$out")" "fastest is marked"
assert_eq "walk 5|ride" "$(q '"|".join([d["connections"][0]["legs"][0]["kind"] + " " + str(d["connections"][0]["legs"][0]["minutes"]), d["connections"][0]["legs"][1]["kind"]])' <<< "$out")" "walk legs carry minutes"
assert_eq "7 2" "$(q 'd["connections"][0]["platform"], d["connections"][0]["delay"]' <<< "$out" | tr -d "(),'")" "platform and delay"

out=$("$C" fetch --reverse --now "$NOW")
assert_eq False "$(q 'd["toWork"]' <<< "$out")" "reverse flips the direction"
out=$("$C" fetch --now $((NOW + 8 * 3600)) || true)
assert_eq False "$(q 'd["toWork"]' <<< "$out")" "afternoon goes home"

cfg=$XDG_CONFIG_HOME/torus/commute.json
setcfg() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); d.update(json.loads(sys.argv[2])); json.dump(d, open(sys.argv[1], 'w'))" "$cfg" "$1"; }
out=$("$C" alert --now "$NOW")
assert_eq "False {'evening': '18:30'}" "$(q 'd["due"], d["slots"]' <<< "$out" | tr -d '()' | sed 's/, {/ {/')" "evening alert on by default, morning off"
setcfg '{"evening": "07:30"}'
out=$("$C" alert --now "$NOW")
assert_eq "True evening" "$(q 'd["due"], d["slot"]' <<< "$out" | tr -d "(),'")" "evening alert due in its window"
q 'd["title"]' <<< "$out" | grep -q '^Trains home, leave in 5 min$' || fail "alert title: $(q 'd["title"]' <<< "$out")"
q 'd["body"]' <<< "$out" | grep -q '^08:05 → 08:55  IC 1  pl. 7  50 min  +2$' || fail "alert body: $(q 'd["body"]' <<< "$out")"
assert_eq False "$(q 'd["due"]' <<< "$("$C" alert --now $((NOW + 60)))")" "an alert shows once a day"
"$C" alert snooze --now $((NOW + 60)) > /dev/null
assert_eq False "$(q 'd["due"]' <<< "$("$C" alert --now $((NOW + 300)))")" "snoozed alert waits"
assert_eq True "$(q 'd["due"]' <<< "$("$C" alert --now $((NOW + 1000)))")" "snoozed alert comes back after 15 min"
setcfg '{"morning": "07:50"}'
out=$("$C" alert --now $((NOW + 1000)))
assert_eq "True morning" "$(q 'd["due"], d["slot"]' <<< "$out" | tr -d "(),'")" "morning alert when enabled"
q 'd["title"]' <<< "$out" | grep -q '^Trains to work' || fail "morning goes to work"
"$C" alert unmute --now "$NOW" > /dev/null
"$C" alert mute --now "$NOW" > /dev/null
out=$("$C" alert --now $((NOW + 1100)))
assert_eq "False True" "$(q 'd["due"], d["muted"]' <<< "$out" | tr -d "(),'")" "muted for today"
"$C" alert unmute --now "$NOW" > /dev/null
assert_eq False "$(q 'd["due"]' <<< "$("$C" alert --now $((NOW + 4 * 86400)))")" "no alerts on Saturday"
echo '{"home": "Home street 1", "work": "Work road 2"}' | "$C" save > /dev/null
assert_eq "07:30 07:50" "$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["evening"], d["morning"])' "$cfg")" "saving addresses keeps the alert times"
setcfg '{"evening": "18:30", "morning": ""}'

rm -rf "$XDG_CACHE_HOME"
"$C" fetch --now "$NOW" > /dev/null
kill "$srv"; wait "$srv" 2> /dev/null || true; srv=
out=$("$C" fetch --now $((NOW + 30)))
assert_eq False "$(q 'd["stale"]' <<< "$out")" "a fresh cache is used without the network"
out=$("$C" fetch --now $((NOW + 120)))
assert_eq "True True" "$(q 'd["ok"], d["stale"]' <<< "$out" | tr -d "(),'")" "offline shows the last result"
rm -rf "$XDG_CACHE_HOME"
out=$("$C" fetch --now $((NOW + 120)) || true)
assert_eq False "$(q 'd["ok"]' <<< "$out")" "offline without a cache is an error"
