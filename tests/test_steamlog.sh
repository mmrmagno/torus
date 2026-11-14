#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin"
printf '#!/bin/sh\nprintf "730\\tCounter-Strike 2\\t0\\t0\\t\\n1145360\\tHades\\t0\\t0\\t\\n413150\\tStardew Valley\\t0\\t0\\t\\n"\n' > "$F/bin/torus-games"
chmod +x "$F/bin/torus-games"
export PATH=$F/bin:$PATH
S=$REPO/home/.local/bin/torus-steamlog

out=$("$S" replay "$REPO/tests/fixtures/steam/shader.tsv")
assert_eq "running:Counter-Strike 2:10:-1
running:Counter-Strike 2:40:60
running:Hades:50:-1
running:Counter-Strike 2:70:30
done:Counter-Strike 2:100:0
stopped:Hades:50:0" "$(jq -r '"\(.state):\(.name):\(.pct):\(.left)"' <<< "$out")" "shader replay: name, percent, time left from the rate, finished, a stalled one stops"
grep -q '"kind": "shader"' <<< "$out" || fail "events are shader kind"

printf '#!/bin/sh\necho x >> %s/games-calls\nprintf "730\\tCounter-Strike 2\\t0\\t0\\t\\n"\n' "$F" > "$F/bin/torus-games"
for i in $(seq 1 9); do printf '%s\tshader_log.txt\t%s\n' "$i" "[x] Still replaying 228980 ($((i * 10))%, $((i * 100))/1000)"; done > "$F/unknown.tsv"
"$S" replay "$F/unknown.tsv" > /dev/null
assert_eq 1 "$(wc -l < "$F/games-calls")" "an app torus-games does not list (Steamworks, Proton) is looked up once, not on every line"
printf '#!/bin/sh\nprintf "730\\tCounter-Strike 2\\t0\\t0\\t\\n1145360\\tHades\\t0\\t0\\t\\n413150\\tStardew Valley\\t0\\t0\\t\\n"\n' > "$F/bin/torus-games"

out=$("$S" replay "$REPO/tests/fixtures/steam/content.tsv")
assert_eq "running:Counter-Strike 2:0:-1:
running:Counter-Strike 2:5:-1:
running:Counter-Strike 2:25:75:9.5 MB/s
running:Counter-Strike 2:45:55:9.5 MB/s
done:Counter-Strike 2:100:0:
running:Stardew Valley:0:-1:
stopped:Stardew Valley:0:0:" "$(jq -r '"\(.state):\(.name):\(.pct):\(.left):\(.speed)"' <<< "$out")" "download: percent from the manifest, speed and time left over the last minute, finished, canceled"
[[ $(jq -r .kind <<< "$out" | sort -u) == download ]] || fail "download kind"
printf '%s\tcontent_log.txt\t%s\n' 1 "[x] AppID 739630 update started : download 0/22660352, store 0/0, reuse 0/104778560" 2 "[x] AppID 739630 Shader update changed : None" 3 "[x] AppID 739630 scheduler finished : removed from schedule (result No Error, state 0xc)" > "$F/shadercache.tsv"
assert_eq "running done" "$("$S" replay "$F/shadercache.tsv" | jq -r .state | paste -sd' ')" "a shader cache download ends with the scheduler line, no finished update"

mkdir -p "$F/steam/steamapps"
printf '"AppState"\n{\n\t"appid"\t\t"730"\n\t"BytesToDownload"\t\t"1000"\n\t"BytesDownloaded"\t\t"300"\n}\n' > "$F/steam/steamapps/appmanifest_730.acf"
mkdir -p "$F/steam/logs"
TORUS_STEAM=$F/steam timeout 10 "$S" follow > "$F/events" &
p=$!
sleep 1
echo "[x] Still replaying 730 (25%, 250/1000)" >> "$F/steam/logs/shader_log.txt"
for _ in $(seq 40); do grep -q pct "$F/events" 2> /dev/null && break; sleep 0.2; done
kill "$p" 2> /dev/null || true
grep -q '"pct": 25' "$F/events" || fail "follow picks up a line appended to the live log: $(cat "$F/events")"
TORUS_STEAM=$F/steam timeout 10 "$S" follow > "$F/events2" &
p=$!
sleep 1
echo "[x] AppID 730 update started : download 0/1000, store 0/0" >> "$F/steam/logs/content_log.txt"
for _ in $(seq 40); do grep -q '"pct": 30' "$F/events2" 2> /dev/null && break; sleep 0.2; done
kill "$p" 2> /dev/null || true
grep -q '"kind": "download", "state": "running", "appid": "730", "name": "Counter-Strike 2", "pct": 30' "$F/events2" || fail "follow reads the manifest while a download runs: $(cat "$F/events2")"
echo "steamlog: ok"
