#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
srv=
trap '[[ -n $srv ]] && kill "$srv" 2> /dev/null; rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/config/torus" "$F/state/torus"

printf '#!/bin/sh\ntouch %s/ran\n' "$F" > "$F/bin/other"; chmod +x "$F/bin/other"
printf '#!/bin/sh\necho picker\n' > "$F/bin/hyprland-share-picker"; chmod +x "$F/bin/hyprland-share-picker"
out=$(PATH=$F/bin:$PATH XDG_STATE_HOME=$F/state TORUS_SHARE_FALLBACK=$F/bin/other "$REPO/home/.local/bin/torus-share-picker")
[[ -e $F/ran ]] && fail "the share picker ran a program named by the environment"
assert_eq picker "$out" "the share picker only falls back to hyprland-share-picker"

port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
python3 -I -c '
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_POST(self):
        open(sys.argv[2], "a").write(str(self.headers.get("Authorization")) + "\n")
        self.send_response(500); self.end_headers()
    do_GET = do_POST
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
' "$port" "$F/seen" & srv=$!
for _ in $(seq 50); do curl -s -o /dev/null "http://127.0.0.1:$port" && break; sleep 0.1; done
: > "$F/seen"
printf 'secret-key\n' > "$F/config/torus/ojp.key"; chmod 600 "$F/config/torus/ojp.key"
echo '{"home": "Home street 1", "work": "Work road 2"}' > "$F/config/torus/commute.json"
C=$(patched "$REPO/home/.local/bin/torus-commute" "$F/bin" https://transport.opendata.ch/v1 http://127.0.0.1:1 https://api.opentransportdata.swiss/ojp20 http://127.0.0.1:1)
XDG_CONFIG_HOME=$F/config XDG_CACHE_HOME=$F/cache XDG_STATE_HOME=$F/state \
  TORUS_COMMUTE_API=http://127.0.0.1:$port TORUS_COMMUTE_OJP=http://127.0.0.1:$port \
  timeout 20 "$C" fetch --to work > /dev/null 2>&1 || true
grep -q secret-key "$F/seen" && fail "the OJP key went to a host named by the environment"
[[ -s $F/seen ]] && fail "the commute addresses went to a host named by the environment"

bad=$(grep -rnE 'TORUS_[A-Z_]*(API|URL|LOCAL|PLACE|OJP|FALLBACK|CLEAR|PORT)\b' "$REPO/home" "$REPO/system" || true)
[[ -z $bad ]] || fail "network addresses, programs and password timing come from the environment: $bad"
echo "envknobs: ok"
