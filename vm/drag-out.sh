#!/usr/bin/env bash
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
qmp=${1:-$HOME/vms/torus/dev.qmp}
vm() { "$here/torus-vm" ssh 'export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1); export PATH=$HOME/.local/bin:$PATH; '"$*" < /dev/null; }
read -r bx by bw bh <<<"$(vm 'hyprctl monitors -j' | jq -r '[.[] | {x, y, w: ((if .transform % 2 == 1 then .height else .width end) / .scale), h: ((if .transform % 2 == 1 then .width else .height end) / .scale)}] | [(map(.x) | min), (map(.y) | min), ((map(.x + .w) | max) - (map(.x) | min)), ((map(.y + .h) | max) - (map(.y) | min))] | map(floor) | join(" ")')"
read -r mx my <<<"$(vm 'hyprctl monitors -j' | jq -r '.[] | select(.name == "Virtual-1") | "\(.x) \(.y)"')"
read -r tx ty <<<"$(vm 'hyprctl monitors -j' | jq -r '.[] | select(.name == "SIDE") | "\(.x + 540) \(.y + 900)"')"
pt() { echo "$(($1 - bx)),$(($2 - by))"; }
drag() {
  local steps=() i
  for i in 1 2 3 4 5; do steps+=("$(pt $(($1 + (tx - $1) * i / 5)) $(($2 + (ty - $2) * i / 5)))"); done
  python3 "$here/qmp-mouse.py" "$qmp" "$bw" "$bh" "$(pt "$1" "$2")" down "$(pt $(($1 - 10)) $(($2 + 10)))" "${steps[@]}" up
}
target() {
  vm 'hyprctl clients -j | jq -r ".[] | select(.class == \"drop-target\") | .pid" | xargs -r kill; sleep 0.5; rm -f /tmp/drop.txt
    hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"SIDE\" }))" > /dev/null
    hyprctl eval "hl.exec_cmd(\"kitty --class drop-target sh -c '\''stty -icanon -echo; cat > /tmp/drop.txt'\''\")" > /dev/null; sleep 2
    hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"Virtual-1\" }))" > /dev/null; qs -c torus ipc call torus closeAll > /dev/null; qs -c torus ipc call torus recallForget > /dev/null'
}
park() { python3 "$here/qmp-mouse.py" "$qmp" "$bw" "$bh" "$(pt $((mx + 640)) $((my + 600)))"; }
got() { vm 'cat /tmp/drop.txt 2> /dev/null'; }
bad=""
vm 'c=~/Videos/Clips/hades; mkdir -p $c; ffmpeg -v error -y -f lavfi -i testsrc=s=640x360:r=30:d=2 -pix_fmt yuv420p $c/hades-2031-01-01-000000.mp4; sleep 1; magick -size 320x180 xc:"#f38ba8" ~/Pictures/Screenshots/torus-drag\ out.png'

target
park
vm 'qs -c torus ipc call torus screenshotShow ~/Pictures/Screenshots/torus-drag\ out.png > /dev/null; sleep 1'
drag $((mx + 476)) $((my + 80)); sleep 1.5
[[ $(got) == "$HOME/Pictures/Screenshots/torus-drag out.png" || $(got) == *"/Pictures/Screenshots/torus-drag out.png" ]] || bad+="island[$(got)] "

target
park
vm 'qs -c torus ipc call torus captureToggle > /dev/null; sleep 1.5'
drag $((mx + 340)) $((my + 390)); sleep 1.5
[[ $(got) == *"/Pictures/Screenshots/torus-drag out.png" ]] || bad+="capture[$(got)] "

target
park
vm 'qs -c torus ipc call torus gamesToggle > /dev/null; sleep 1.5; wtype -M ctrl -k Tab -m ctrl; sleep 2.5'
drag $((mx + 200)) $((my + 310)); sleep 1.5
[[ $(got) == *"/Videos/Clips/hades/hades-2031-01-01-000000.mp4" ]] || bad+="clip[$(got)] "

vm 'qs -c torus ipc call torus closeAll > /dev/null; hyprctl clients -j | jq -r ".[] | select(.class == \"drop-target\") | .pid" | xargs -r kill; rm -f ~/Pictures/Screenshots/torus-drag\ out.png ~/Videos/Clips/hades/hades-2031-01-01-000000.mp4 /tmp/drop.txt'
if [[ -z $bad ]]; then echo "drag-out: ok the island screenshot, a capture tile and a game clip drop into kitty as their file paths"; else echo "drag-out: FAIL $bad"; exit 1; fi
