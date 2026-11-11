#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
pids=()
trap 'kill "${pids[@]}" 2> /dev/null; rm -rf "$F"' EXIT
export XDG_CONFIG_HOME=$F/config PATH=$F/bin:$PATH
mkdir -p "$F/bin" "$F/proj" "$F/config/torus"
cp "$(command -v sleep)" "$F/bin/steam"
cp "$(command -v sleep)" "$F/bin/myapi"
(cd "$F/proj" && exec sleep 300) & pids+=($!); dev=$!
"$F/bin/steam" 300 & pids+=($!); steam=$!
"$F/bin/myapi" 300 & pids+=($!); api=$!
cat > "$F/bin/ss" <<EOF
#!/usr/bin/env bash
cat <<'L'
LISTEN 0      511        127.0.0.1:5173      0.0.0.0:*    users:(("sleep",pid=$dev,fd=20))
LISTEN 0      511            [::1]:5173         [::]:*    users:(("sleep",pid=$dev,fd=21))
LISTEN 0      4096       127.0.0.1:27036     0.0.0.0:*    users:(("steam",pid=$steam,fd=3))
LISTEN 0      4096         0.0.0.0:8000      0.0.0.0:*    users:(("myapi",pid=$api,fd=3))
LISTEN 0      4096       127.0.0.1:631       0.0.0.0:*
L
EOF
chmod +x "$F/bin/ss"
sleep 0.2
P=$REPO/home/.local/bin/torus-ports

out=$("$P" list)
assert_eq 2 "$(wc -l <<< "$out")" "one row per port, steam and rootless sockets skipped: $out"
assert_eq "5173	$dev	sleep	$F/proj	sleep 300	127.0.0.1" "$(head -1 <<< "$out")" "dev server row"
assert_eq "8000	$api	myapi" "$(sed -n 2p <<< "$out" | cut -f1-3)" "second server"

echo myapi > "$F/config/torus/ports-ignore"
assert_eq 1 "$("$P" list | wc -l)" "ignore file"
rm "$F/config/torus/ports-ignore"

"$P" stop 1 2> /dev/null && fail "refuses a pid that is not a listed server"
"$P" stop abc 2> /dev/null && fail "refuses junk"
"$P" stop "$dev" || fail "stops a listed server"
for _ in $(seq 20); do kill -0 "$dev" 2> /dev/null || break; sleep 0.1; done
kill -0 "$dev" 2> /dev/null && fail "server still running"
true
