#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
srv=
trap '[[ -n $srv ]] && kill "$srv" 2> /dev/null; rm -rf "$F"' EXIT
mkdir -p "$F/www/api" "$F/config/torus" "$F/drm"
echo '{"models":[{"name":"llama3.2:3b","size":2000000000},{"name":"qwen2.5:14b","size":9000000000},{"name":"llama3.3:70b","size":42000000000}]}' > "$F/www/api/tags"
port=$((20000 + RANDOM % 20000))
python3 -m http.server -d "$F/www" -b 127.0.0.1 "$port" > /dev/null 2>&1 & srv=$!
for _ in $(seq 50); do curl -sf "http://127.0.0.1:$port/api/tags" > /dev/null && break; sleep 0.1; done
export XDG_CONFIG_HOME=$F/config TORUS_AI_MEMINFO=$F/meminfo TORUS_AI_VRAM="$F/drm/vram*"
H=$REPO/home/.local/bin/torus-ai-host

echo "MemTotal: 32000000 kB" > "$F/meminfo"; echo 17163091968 > "$F/drm/vram0"
out=$(TORUS_AI_LOCAL=http://127.0.0.1:$port "$H")
assert_eq "online:qwen2.5:14b:false" "$(jq -r '"\(.status):\(.pick):\(.remote)"' <<< "$out")" "desktop with 16 GB VRAM picks the biggest model that fits"
rm "$F/drm/vram0"; echo "MemTotal: 16000000 kB" > "$F/meminfo"
assert_eq "llama3.2:3b" "$(TORUS_AI_LOCAL=http://127.0.0.1:$port "$H" | jq -r .pick)" "laptop without VRAM picks the 3B model"
assert_eq "offline" "$(TORUS_AI_LOCAL=http://127.0.0.1:1 "$H" | jq -r .status)" "no ollama, no remote"
echo "{\"remote\": \"http://127.0.0.1:$port\"}" > "$F/config/torus/ai.json"
out=$(TORUS_AI_LOCAL=http://127.0.0.1:1 "$H")
assert_eq "true:qwen2.5:14b:http://127.0.0.1:$port" "$(jq -r '"\(.remote):\(.pick):\(.url)"' <<< "$out")" "laptop falls back to the desktop's ollama, sized for the desktop (remote_budget_gb, 12 by default)"
echo "ai host: ok"
