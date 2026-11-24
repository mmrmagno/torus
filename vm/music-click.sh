#!/usr/bin/env bash
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
qmp=${1:-$HOME/vms/torus/dev.qmp}
vm() { "$here/torus-vm" ssh 'export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1); export PATH=$HOME/.local/bin:$PATH; '"$*"; }
box=$(vm 'hyprctl monitors -j | jq -r "[(map(.x) | min), (map(.y) | min), (map(.x + (if .transform % 2 == 1 then .height else .width end)) | max), (map(.y + (if .transform % 2 == 1 then .width else .height end)) | max)] | @tsv"')
read -r x0 y0 x1 y1 <<< "$box"
click() { python3 "$here/qmp-mouse.py" "$qmp" $((x1 - x0)) $((y1 - y0)) "$(($1 - x0 - 1)),$(($2 - y0))" "$(($1 - x0)),$(($2 - y0))" click; }
bad=""
vm 'Q="qs -c torus ipc call torus"; $Q closeAll; sleep 0.6; hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"Virtual-1\" }))" > /dev/null; $Q musicToggle; sleep 1.5; wtype -M ctrl -k comma -m ctrl; sleep 1' > /dev/null
read -r px py pw < <(vm 'hyprctl layers -j | jq -r ".. | objects | select(.namespace? == \"torus-panel\") | [.x, .y, .w] | @tsv" | head -1')
[[ $(vm 'qs -c torus ipc call torus musicSpot | tail -1') == *"|settings" ]] || bad+="settings-did-not-open "
click $((px + pw - 36)) $((py + 36))
sleep 1
[[ $(vm 'qs -c torus ipc call torus musicSpot | tail -1') == *"|settings" ]] && bad+="x-did-not-close "
vm 'qs -c torus ipc call torus closeAll' > /dev/null
if [[ -z $bad ]]; then echo "music-click: ok the X in music settings closes the sheet (the cog under it no longer reopens it)"; else echo "music-click: FAIL $bad"; exit 1; fi
