#!/usr/bin/env bash
# Boots the dev VM, runs vm/parity.sh on the committed branch, records one line for torus doctor, shuts the VM down.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=${TORUS_NIGHTLY_REPO:-$(cd "$HERE/.." && pwd)}
V=${TORUS_VM_DIR:-$HOME/vms/torus}
VM=${TORUS_NIGHTLY_VM:-dev}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/torus
LOGDIR=${XDG_CACHE_HOME:-$HOME/.cache}/torus/nightly
TOOL=$HERE/torus-vm
GAMES='cs2|gamescope|hl2_linux|steam_app.*'
mkdir -p "$STATE" "$LOGDIR"
log=$LOGDIR/$(date +%F).log
exec > >(tee -a "$log") 2>&1

record() {
  printf '%s\t%s\t%s\n' "$(date -Iseconds)" "$1" "$2" > "$STATE/parity-nightly"
  echo "nightly: $1 $2"
}

gaming() { ps -eo comm= | grep -qxE "$GAMES"; }

gaming && { record skipped "a game was running"; exit 0; }
[[ -e $V/$VM.qcow2 ]] || { record skipped "no $VM VM"; exit 0; }
[[ -f $V/password ]] || { record skipped "no VM password file"; exit 0; }
pgrep -f "qemu-system.*$V/" > /dev/null && { record skipped "a VM was already running"; exit 0; }

rev=$(git -C "$REPO" rev-parse --short HEAD 2> /dev/null || echo "?")
branch=$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2> /dev/null || echo "?")
snap=$(mktemp -d)
trap 'rm -rf "$snap"; "$TOOL" down "$VM" > /dev/null 2>&1' EXIT
mkdir -p "$snap/torus-dev"
git -C "$REPO" archive HEAD | tar -x -C "$snap/torus-dev"

"$TOOL" start "$VM" || { record fail "VM did not boot"; exit 1; }
G='export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 LANG=C.UTF-8 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr 2>/dev/null | head -1); export PATH=$HOME/.local/bin:$PATH;'
g() { "$TOOL" ssh "$G $*"; }
for _ in $(seq 60); do g 'qs -c torus ipc call torus stayAwake true' > /dev/null 2>&1 && break; sleep 3; done

if [[ $(g 'qs -c torus ipc call torus isLocked 2>/dev/null | tail -1') == true ]]; then
  python3 "$HERE/qmp-keys.py" "$V/$VM.qmp" "shift_r+ 20 shift_r- 400 $(for _ in $(seq 60); do printf 'backspace+ 8 backspace- 8 '; done)"
  python3 "$HERE/qmp-keys.py" "$V/$VM.qmp" "$(python3 "$HERE/qmp-text.py" "$V/password") ret+ 20 ret- 20"
  sleep 3
fi

"$TOOL" push "$snap/torus-dev" > /dev/null
g 'rsync -a --delete ~/torus-dev/ ~/torus/ && rm -rf ~/torus-dev && ~/torus/install.sh --no-packages > /dev/null 2>&1; hyprctl reload > /dev/null; systemctl --user daemon-reload; systemctl --user restart torus-shell; sleep 8; qs -c torus ipc call torus stayAwake true' > /dev/null 2>&1
g 'hyprctl monitors -j | jq -r ".[].name" | grep -qx SIDE || hyprctl output create headless SIDE; hyprctl eval "hl.monitor({ output = \"SIDE\", mode = \"1920x1080\", position = \"1280x0\", scale = 1, transform = 3 })"' > /dev/null 2>&1

(while sleep 20; do gaming && { echo "nightly: a game started, stopping the VM"; "$TOOL" down "$VM" > /dev/null 2>&1; break; }; done) &
watch=$!
out=$(g 'LOCK_PW="$(cat)" ~/torus/vm/parity.sh all' < "$V/password" 2>&1)
kill "$watch" 2> /dev/null
echo "$out"
score=$(grep -oE '^parity: [0-9]+/[0-9]+' <<< "$out" | tail -1 | cut -d' ' -f2)
fails=$(grep -E '^[a-z0-9]+: FAIL' <<< "$out" | cut -d: -f1 | tr '\n' ' ')
if [[ -z $score ]]; then
  record fail "parity did not finish ($branch@$rev)"
  exit 1
elif [[ -n $fails ]]; then
  record fail "$score on $branch@$rev, failed: $fails"
  exit 1
fi
record ok "$score on $branch@$rev"
