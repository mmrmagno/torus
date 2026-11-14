#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

Q=$REPO/home/.config/quickshell/torus
bare=$(grep -rn --include='*.qml' -E 'execDetached\(\["(kitty|xdg-open|firefox|steam|torus-layout|nvim|satty|pavucontrol|nm-connection-editor|dolphin|mpv)"|\.execute\(\)|openUrlExternally|execDetached\(\["sh", "-c", "[^"]*(xdg-open|command -v firefox|sleep 0\.35)' "$Q" || true)
[[ -z $bare ]] || fail "apps started from the shell must go through torus-launch, or a shell restart kills them:
$bare"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/run/systemd" "$F/work"
printf '#!/bin/sh\necho "$PWD|$*" > "%s/called"\n' "$F" > "$F/bin/systemd-run"; chmod +x "$F/bin/systemd-run"
python3 -c "import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])" "$F/run/systemd/private"
L=$REPO/home/.local/bin/torus-launch
XDG_RUNTIME_DIR=$F/run PATH=$F/bin:$PATH "$L" --dir "$F/work" kitty -e nvim x
assert_eq "$F/work|--user --scope --quiet --collect --slice=app.slice -- kitty -e nvim x" "$(cat "$F/called")" "own scope, in the asked directory"
assert_eq "plain" "$(XDG_RUNTIME_DIR=$F/none PATH=$F/bin:$PATH "$L" echo plain)" "runs directly without a user manager"
assert_fails "$L"
echo "launch: ok"
