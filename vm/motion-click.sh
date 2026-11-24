#!/usr/bin/env bash
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
qmp=${1:-$HOME/vms/torus/dev.qmp}
vm() { "$here/torus-vm" ssh 'export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1); export PATH=$HOME/.local/bin:$PATH; '"$*"; }
read -r x0 y0 x1 y1 < <(vm 'hyprctl monitors -j | jq -r "[(map(.x) | min), (map(.y) | min), (map(.x + (if .transform % 2 == 1 then .height else .width end)) | max), (map(.y + (if .transform % 2 == 1 then .width else .height end)) | max)] | @tsv"')
click() { python3 "$here/qmp-mouse.py" "$qmp" $((x1 - x0)) $((y1 - y0)) "$(($1 - x0 - 1)),$(($2 - y0))" "$(($1 - x0)),$(($2 - y0))" click; }
bad="" out=""
vm 'qs -c torus ipc call torus closeAll; hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"Virtual-1\" }))"' > /dev/null 2>&1
read -r px py < <(vm 'hyprctl layers -j | jq -r "to_entries[] | select(.key == \"Virtual-1\") | .value.levels[][] | select(.namespace == \"torus-bar\") | [.x, .y] | @tsv"')
for spec in updates:updates network:network clock:dashboard notifications:center clipboard:clip; do
  mod=${spec%%:*} panel=${spec#*:}
  read -r bx bw < <(vm "qs -c torus ipc call torus barBoxes Virtual-1 | tail -1 | jq -r '.modules.$mod | [.x, .w] | @tsv'")
  [[ -n $bx ]] || { bad+="$mod-not-in-bar "; continue; }
  want=$((px + bx + bw / 2))
  click "$want" $((py + 14)); sleep 1.2
  IFS='|' read -r p at reach w < <(vm "qs -c torus ipc call torus panelMotion $panel | tail -1")
  lx=$(vm 'hyprctl layers -j | jq -r "to_entries[] | select(.key == \"Virtual-1\") | .value.levels[][] | select(.namespace == \"torus-panel\") | .x" | head -1')
  got=$((${lx:-0} + ${at%%,*}))
  ((got >= want - 4 && got <= want + 4 && ${at##*,} < 0)) || bad+="$panel[origin $got,${at##*,} icon $want] "
  [[ $p == 1.00 && $reach == 0.90 ]] || bad+="$panel[p $p reach $reach] "
  out+="$panel "
  vm 'qs -c torus ipc call torus closeAll' > /dev/null; sleep 0.6
done
vm 'qs -c torus ipc call torus dashboardToggle; sleep 0.8' > /dev/null
IFS='|' read -r p at reach w < <(vm 'qs -c torus ipc call torus panelMotion dashboard | tail -1')
[[ $at == $((w / 2)),0 && $reach == 0.96 ]] || bad+="key-opens-from-the-edge[$at of $w, $reach] "
vm 'qs -c torus ipc call torus closeAll' > /dev/null
if [[ -z $bad ]]; then echo "motion-click: ok panels grow from the bar icon that was clicked ($out), from the screen edge for a key"; else echo "motion-click: FAIL $bad"; exit 1; fi
