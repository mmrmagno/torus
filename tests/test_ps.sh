#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export TORUS_PS_PROC=$F/proc XDG_RUNTIME_DIR=$F
P=$REPO/home/.local/bin/torus-ps

proc() {
  local pid=$1 name=$2 state=$3 ticks=$4 rss=$5
  mkdir -p "$F/proc/$pid/fdinfo"
  echo "$pid ($name) $state 1 0 0 0 0 0 0 0 0 0 $ticks 0 0 0 20 0 1 0 0 0 $rss" > "$F/proc/$pid/stat"
  printf '%s\0--flag\0' "/usr/bin/$name" > "$F/proc/$pid/cmdline"
}
proc 100 "game (x)" S 100 1000
proc 200 editor S 50 10
proc 300 dead Z 0 0
printf 'drm-client-id:\t7\ndrm-memory-vram:\t2048 KiB\n' > "$F/proc/100/fdinfo/5"
printf 'drm-client-id:\t7\ndrm-memory-vram:\t2048 KiB\n' > "$F/proc/100/fdinfo/6"
printf 'drm-client-id:\t8\ndrm-memory-vram:\t1 MiB\n' > "$F/proc/100/fdinfo/7"
printf 'pos:\t0\n' > "$F/proc/200/fdinfo/1"

q() { python3 -c "import json,sys; d=json.load(sys.stdin); p={r['pid']: r for r in d['processes']}; print($1)"; }
out=$("$P")
assert_eq "[100, 200]" "$(q 'sorted(p)' <<< "$out")" "zombies are left out"
assert_eq "game (x)" "$(q 'p[100]["name"]' <<< "$out")" "names with spaces and brackets"
assert_eq "/usr/bin/game (x) --flag" "$(q 'p[100]["cmd"]' <<< "$out")" "command line"
assert_eq $((3 * 1048576)) "$(q 'p[100]["gpu"]' <<< "$out")" "GPU memory counted once per client"
assert_eq 0 "$(q 'p[200]["gpu"]' <<< "$out")" "no GPU without a drm client"
assert_eq "0.0" "$(q 'p[100]["cpu"]' <<< "$out")" "first sample has no CPU yet"
proc 100 "game (x)" S 400 1000
sleep 0.3
out=$("$P")
python3 -c "import json,sys; d=json.load(sys.stdin); p={r['pid']: r for r in d['processes']}; sys.exit(0 if p[100]['cpu'] > p[200]['cpu'] == 0 else 1)" <<< "$out" || fail "CPU from the change since the last sample: $out"
assert_eq 100 "$(q 'd["processes"][0]["pid"]' <<< "$out")" "busiest first"
"$P" kill 1 > /dev/null && fail "refuses PID 1"
assert_eq "already gone" "$("$P" kill 999999 | python3 -c 'import json,sys; print(json.load(sys.stdin)["message"])')" "missing PID"
