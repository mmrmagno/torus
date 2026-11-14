#!/usr/bin/env bash
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
qmp=${1:-$HOME/vms/torus/dev.qmp}
vm() { "$here/torus-vm" ssh 'export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1); export PATH=$HOME/.local/bin:$PATH; '"$*"; }
click() { python3 "$here/qmp-mouse.py" "$qmp" 3840 1440 "$(($1 - 10)),20" "$1,18" click; }
bad=""
vm 'hyprctl eval "hl.monitor({ output = \"SIDE\", mode = \"2560x1440\", position = \"1280x0\", scale = 1, transform = 0 })" > /dev/null; sleep 2'
for round in 1 2 3; do
  vm 'Q="qs -c torus ipc call torus"; $Q closeAll; $Q barToggle; sleep 1; $Q barToggle; sleep 2' > /dev/null
  click 1280
  sleep 1
  [[ $(vm 'qs -c torus ipc call torus isOpen dashboard | tail -1') == true ]] || bad+="idle-click-$round "
  vm 'qs -c torus ipc call torus closeAll' > /dev/null
done
vm 'Q="qs -c torus ipc call torus"; f=~/Pictures/Screenshots/torus-parity-undoclick.png; magick -size 64x64 xc:red $f; $Q screenshotShow $f > /dev/null; sleep 0.6; $Q screenshotAct Delete > /dev/null; sleep 1.2' > /dev/null
click 1420
sleep 2
vm 'ls ~/Pictures/Screenshots/torus-parity-undoclick.png' > /dev/null 2>&1 || bad+="undo-click "
vm 'rm -f ~/Pictures/Screenshots/torus-parity-undoclick.png; hyprctl reload > /dev/null' > /dev/null
if [[ -z $bad ]]; then echo "island-click: ok the island takes clicks after the bar hid and came back (idle opens the dashboard, Undo restores)"; else echo "island-click: FAIL $bad"; exit 1; fi
