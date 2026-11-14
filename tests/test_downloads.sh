#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
P=""
trap '[[ -n $P ]] && kill "$P" 2> /dev/null; rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/dl"
printf '#!/bin/sh\necho "notify $*" >> "%s/log"\necho open\n' "$F" > "$F/bin/notify-send"
printf '#!/bin/sh\necho "launch $*" >> "%s/log"\n' "$F" > "$F/bin/torus-launch"
chmod +x "$F/bin/"*
export PATH=$F/bin:$PATH TORUS_DOWNLOADS=$F/dl
"$REPO/home/.local/bin/torus-downloads" follow > "$F/ev" &
P=$!
sleep 0.5
wait_for() { for _ in $(seq 50); do grep -q "$1" "$2" 2> /dev/null && return 0; sleep 0.1; done; return 1; }

: > "$F/dl/song.flac"
head -c 100000 /dev/urandom > "$F/dl/song.flac.part"
sleep 1.1
head -c 300000 /dev/urandom >> "$F/dl/song.flac.part"
wait_for '"speed": "[0-9]' "$F/ev" || fail "progress with size and speed: $(cat "$F/ev")"
mv "$F/dl/song.flac.part" "$F/dl/song.flac"
wait_for '"state": "done"' "$F/ev" || fail "firefox rename finishes: $(cat "$F/ev")"
jq -e 'select(.state == "running") | .pct == -1 and .name == "song.flac"' "$F/ev" > /dev/null || fail "running job named after the final file"
wait_for "launch xdg-open $F/dl/song.flac" "$F/log" || fail "Open from the notification opens the file: $(cat "$F/log")"
grep -q 'notify -a Downloads -i folder-download -A open=Open -A folder=Show in folder Downloaded song.flac' "$F/log" || fail "notification with Open and Show in folder"

head -c 5000 /dev/urandom > "$F/dl/Unconfirmed 4711.crdownload"
sleep 0.3
mv "$F/dl/Unconfirmed 4711.crdownload" "$F/dl/setup.iso.crdownload"
head -c 5000 /dev/urandom >> "$F/dl/setup.iso.crdownload"
sleep 0.3
mv "$F/dl/setup.iso.crdownload" "$F/dl/setup.iso"
wait_for '"name": "setup.iso", "path"' "$F/ev" || fail "chromium rename chain finishes: $(cat "$F/ev")"

: > "$F/dl/big.zip"
head -c 5000 /dev/urandom > "$F/dl/big.zip.part"
sleep 0.3
rm "$F/dl/big.zip.part" "$F/dl/big.zip"
wait_for '"state": "stopped", "id": "big.zip.part"' "$F/ev" || fail "a canceled download just stops: $(cat "$F/ev")"
[[ $(grep -c 'notify ' "$F/log") == 2 ]] || fail "no notification for a canceled one: $(cat "$F/log")"
echo "downloads: ok"
