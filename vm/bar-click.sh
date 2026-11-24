#!/usr/bin/env bash
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
qmp=${1:-$HOME/vms/torus/dev.qmp}
vm() { "$here/torus-vm" ssh 'export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1); export PATH=$HOME/.local/bin:$PATH; '"$*"; }
read -r x0 y0 x1 y1 < <(vm 'hyprctl monitors -j | jq -r "[(map(.x) | min), (map(.y) | min), (map(.x + (if .transform % 2 == 1 then .height else .width end)) | max), (map(.y + (if .transform % 2 == 1 then .width else .height end)) | max)] | @tsv"')
click() { python3 "$here/qmp-mouse.py" "$qmp" $((x1 - x0)) $((y1 - y0)) "$(($1 - x0 - 1)),$(($2 - y0))" "$(($1 - x0)),$(($2 - y0))" click; }
bad=""
vm 'qs -c torus ipc call torus closeAll; hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"Virtual-1\" }))" > /dev/null; kitty --class barclick sh -c "sleep 30" > /dev/null 2>&1 & sleep 2; hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = \"empty\" }))" > /dev/null; sleep 1' > /dev/null 2>&1
read -r px py < <(vm 'hyprctl layers -j | jq -r "to_entries[] | select(.key == \"Virtual-1\") | .value.levels[][] | select(.namespace == \"torus-bar\") | [.x, .y] | @tsv"')
box() { vm "qs -c torus ipc call torus barBoxes Virtual-1 | tail -1 | jq -r '.modules.$1 | [.x, .w] | @tsv'"; }
before=$(vm 'hyprctl activeworkspace -j | jq .id')
read -r wx ww < <(box workspaces)
click $((px + wx + 10)) $((py + 1)); sleep 1
now=$(vm 'hyprctl activeworkspace -j | jq .id')
[[ $now != "$before" ]] || bad+="workspace-top-edge[$before stays] "
read -r ux uw < <(box updates)
click $((px + ux + uw / 2 + 12)) $((py + 1)); sleep 1.5
[[ $(vm 'qs -c torus ipc call torus isOpen updates | tail -1') == true ]] || bad+="updates-corner "
vm 'qs -c torus ipc call torus closeAll; pkill -f "class barclick"' > /dev/null
if [[ -z $bad ]]; then echo "bar-click: ok a click on the top pixel row of the bar switches the workspace, 12 px beside an icon still hits it"; else echo "bar-click: FAIL $bad"; exit 1; fi
