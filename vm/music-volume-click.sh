#!/usr/bin/env bash
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
qmp=${1:-$HOME/vms/torus/dev.qmp}
vm() { "$here/torus-vm" ssh 'export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1); export PATH=$HOME/.local/bin:$PATH; '"$*"; }
read -r x0 y0 x1 y1 < <(vm 'hyprctl monitors -j | jq -r "[(map(.x) | min), (map(.y) | min), (map(.x + (if .transform % 2 == 1 then .height else .width end)) | max), (map(.y + (if .transform % 2 == 1 then .width else .height end)) | max)] | @tsv"')
click() { python3 "$here/qmp-mouse.py" "$qmp" $((x1 - x0)) $((y1 - y0)) "$(($1 - x0 - 1)),$(($2 - y0))" "$(($1 - x0)),$(($2 - y0))" click; }
bad=""
vm 'Q="qs -c torus ipc call torus"; $Q closeAll; hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"Virtual-1\" }))" > /dev/null; torus-music index > /dev/null 2>&1; torus-music play random local > /dev/null; torus-music volume 1 > /dev/null; sleep 2; $Q musicToggle; sleep 1.5' > /dev/null
main=$(vm 'wpctl get-volume @DEFAULT_AUDIO_SINK@')
read -r px py < <(vm 'hyprctl layers -j | jq -r ".. | objects | select(.namespace? == \"torus-panel\") | [.x, .y] | @tsv" | head -1')
spot=$(vm 'qs -c torus ipc call torus musicVol | tail -1')
[[ $spot == 100\|on\|stream\|* ]] || bad+="start[$spot] "
IFS=, read -r sx sy sw <<< "${spot##*|}"
click $((px + sx)) $((py + sy)); sleep 1
now=$(vm 'qs -c torus ipc call torus musicVol | tail -1')
stream=$(vm 'wpctl get-volume $(pw-dump | jq -r "[.[] | select(.info.props.\"node.name\" == \"torus-music\") | .id] | first")')
(( ${now%%|*} >= 43 && ${now%%|*} <= 57 )) || bad+="slider[$now] "
[[ $stream == *0.${now%%|*}* ]] || bad+="stream[$stream] "
click $((px + sx - sw / 2 - 27)) $((py + sy)); sleep 1
now=$(vm 'qs -c torus ipc call torus musicVol | tail -1')
[[ $now == *"|muted|"* ]] || bad+="mute[$now] "
click $((px + sx - sw / 2 - 27)) $((py + sy)); sleep 1
[[ $(vm 'wpctl get-volume @DEFAULT_AUDIO_SINK@') == "$main" ]] || bad+="main-output-moved "
vm 'torus-music volume 1 > /dev/null; torus-music clear > /dev/null; qs -c torus ipc call torus closeAll' > /dev/null
if [[ -z $bad ]]; then echo "music-volume-click: ok a click on the slider sets the music stream, the speaker mutes it, the main output stays"; else echo "music-volume-click: FAIL $bad"; exit 1; fi
