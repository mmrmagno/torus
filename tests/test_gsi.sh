#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
G=""
trap '[[ -n $G ]] && kill "$G" 2> /dev/null; rm -rf "$F"' EXIT
mkdir -p "$F/bin"
export PATH=$F/bin:$REPO/home/.local/bin:$PATH HOME=$F XDG_STATE_HOME=$F/state XDG_CONFIG_HOME=$F/config XDG_CACHE_HOME=$F/cache XDG_VIDEOS_DIR=$F/Videos
printf '#!/bin/sh\nexit 0\n' > "$F/bin/qs"
printf '#!/bin/sh\nprintf "730\\tCounter-Strike 2\\t0\\t0\\t\\n"\n' > "$F/bin/torus-games"
chmod +x "$F/bin/qs" "$F/bin/torus-games"
P=$REPO/home/.local/bin/torus-play
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
export TORUS_GSI_SAVE_DELAY=0 TORUS_STEAM=$F/steam
mkdir -p "$F/gsibin"
S=$(patched "$REPO/home/.local/bin/torus-gsi" "$F/gsibin" "PORT = 3471" "PORT = $port")
export PATH=$F/gsibin:$PATH
printf '#!/bin/sh\necho "$*" >> "%s/pkill.log"\n[ "$1" = -USR1 ] && cat "%s/state/torus/gsi-pending" >> "%s/saves"\nexit 0\n' "$F" "$F" "$F" > "$F/bin/pkill"
chmod +x "$F/bin/pkill"

cfg=$F/steam/steamapps/common/Counter-Strike\ Global\ Offensive/game/csgo/cfg
"$S" install | grep -q "not installed" || fail "install without CS2 is a no-op"
mkdir -p "$cfg"
"$S" install > /dev/null
assert_file "$cfg/gamestate_integration_torus.cfg"
tok=$(cat "$F/state/torus/gsi-token")
[[ $(stat -c %a "$F/state/torus/gsi-token") == 600 ]] || fail "token is private"
[[ $(stat -c %a "$cfg/gamestate_integration_torus.cfg") == 600 ]] || fail "the cfg holding the token is private"
grep -q "\"token\" \"$tok\"" "$cfg/gamestate_integration_torus.cfg" || fail "cfg carries the token"
grep -q "\"uri\" \"http://127.0.0.1:$port/\"" "$cfg/gamestate_integration_torus.cfg" || fail "cfg points at 127.0.0.1 only"

run_match() {
  rm -f "$F/saves" "$F/codes" "$F/state/torus/gsi-match.json"
  "$S" serve & G=$!
  for _ in $(seq 50); do (exec 3<>/dev/tcp/127.0.0.1/$port) 2> /dev/null && break; sleep 0.1; done
  ss -ltnH "sport = :$port" | grep -q "127.0.0.1:$port" || fail "the listener is not on 127.0.0.1"
  ss -ltnH "sport = :$port" | grep -qE "(0\.0\.0\.0|\*|\[::\]):$port" && fail "listens on all interfaces"
  while IFS= read -r line; do
    curl -s -o /dev/null -w '%{http_code}\n' -H 'Content-Type: application/json' --data "${line//TOKEN/$tok}" "http://127.0.0.1:$port/" >> "$F/codes"
  done < "$REPO/tests/fixtures/gsi/match.jsonl"
  for _ in $(seq 20); do [[ $(wc -l < "$F/codes") == $(wc -l < "$REPO/tests/fixtures/gsi/match.jsonl") ]] && break; sleep 0.1; done
  [[ -z $(grep -v '^200$' "$F/codes") ]] || fail "every update with the right token is accepted: $(sort "$F/codes" | uniq -c | tr '\n' ' ')"
  kill "$G"; wait "$G" 2> /dev/null || true; G=""
}

run_match
assert_eq "ace clutch 3k" "$(paste -sd' ' "$F/saves")" "saves on an ace, a clutch and a 3K; not twice per round, not for a player being spectated"
assert_eq "de_mirage:2:3:CT:11:2:2:5:1:3" "$(jq -r '"\(.map):\(.ct):\(.t):\(.team):\(.kills):\(.deaths):\(.mvps):\(.best):\(.best_round):\(.auto)"' "$F/state/torus/gsi-match.json")" "match stats for the recap"

"$P" set 730 hl_clutch off
run_match
assert_eq "ace 3k" "$(paste -sd' ' "$F/saves")" "clutch switched off"
"$P" set 730 highlights off
run_match
[[ -s $F/saves ]] && fail "auto highlights off saves nothing: $(cat "$F/saves")"
assert_eq 0 "$(jq -r .auto "$F/state/torus/gsi-match.json")" "no auto clips counted while off"

"$S" serve & G=$!
for _ in $(seq 50); do (exec 3<>/dev/tcp/127.0.0.1/$port) 2> /dev/null && break; sleep 0.1; done
assert_eq 403 "$(curl -s -o /dev/null -w '%{http_code}' --data '{"auth":{"token":"nope"},"round":{"phase":"over"}}' "http://127.0.0.1:$port/")" "a wrong token is refused"
assert_eq 405 "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/")" "GET is refused"
kill "$G"; wait "$G" 2> /dev/null || true; G=""

"$P" set 730 highlights on
"$P" set 730 hl_clutch on
echo '{"appid": "730", "class": "cs2", "name": "Counter-Strike 2", "start": 1, "clips": 0, "gsi": true, "replay_secs": 60}' > "$F/state/torus/play-session.json"
echo ace > "$F/state/torus/gsi-pending"
touch "$F/raw.mp4"
dest=$("$P" saved "$F/raw.mp4")
[[ $dest =~ /Clips/counter-strike-2/counter-strike-2-ace-[0-9-]+\.mp4$ ]] || fail "auto clip named by its event: $dest"
assert_absent "$F/state/torus/gsi-pending"
touch "$F/raw2.mp4"
dest2=$("$P" saved "$F/raw2.mp4")
[[ $dest2 =~ /counter-strike-2-[0-9-]+\.mp4$ ]] || fail "a manual clip has no event: $dest2"
printf '#!/bin/sh\nexit 0\n' > "$F/bin/ffmpeg"; chmod +x "$F/bin/ffmpeg"
assert_eq "ace" "$("$P" clips 730 | awk -F'\t' -v d="$dest" '$1 == d { print $5 }')" "the clip strip gets an auto badge"
echo '{"map":"de_mirage","ct":2,"t":3,"team":"CT","kills":11,"deaths":2,"mvps":2,"best":5,"best_round":1,"auto":1,"start":2}' > "$F/state/torus/gsi-match.json"
cp "$F/state/torus/play-session.json" "$F/session.bak"
"$P" end
grep -q -- '-f torus-gsi serve' "$F/pkill.log" || fail "the game ending stops the listener"
txt=$("$P" recap | jq -r .text)
[[ $txt == "Counter-Strike 2: de_mirage 2:3 · 11/2 K/D · 2 MVPs · "*"best round ace (round 1)"*"2 clips saved (1 auto)" ]] || fail "recap: $txt"

"$S" uninstall > /dev/null
assert_absent "$cfg/gamestate_integration_torus.cfg"
echo "gsi: ok"
