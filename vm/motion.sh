#!/usr/bin/env bash
# usage: motion.sh <open> [close] [hold]; open/close: an IPC call, exec:<cmd> or sh:<cmd>. MOTION_NS/MOTION_CROP pick the target
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)}
export HYPRLAND_INSTANCE_SIGNATURE
QS=(qs -c torus ipc call torus)

run() {
  case $1 in
    exec:*) hyprctl eval "hl.exec_cmd(\"${1#exec:}\")" > /dev/null ;;
    sh:*) sh -c "${1#sh:}" > /dev/null 2>&1 ;;
    *) local a; read -ra a <<<"$1"; "${QS[@]}" "${a[@]}" > /dev/null ;;
  esac
}
open=${1:?usage: motion.sh <open-ipc> [close-ipc] [hold]}
close=${2:-$1}
hold=${3:-1.2}
out=${MOTION_DIR:-$(mktemp -d)}
mkdir -p "$out"
[[ -n ${MOTION_OUTPUT:-} ]] && { hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$MOTION_OUTPUT\" }))" > /dev/null; sleep 0.2; }
mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
size=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.width) \(.height) \(.transform) \(.x) \(.y)"')
read -r mw mh mt mx my <<<"$size"
((mt % 2 == 1)) && { t=$mw; mw=$mh; mh=$t; }
"${QS[@]}" donutPaused true > /dev/null 2>&1
"${QS[@]}" widgetsQuiet true > /dev/null 2>&1
sleep 0.2
rec="" poll=""
trap '"${QS[@]}" donutPaused false > /dev/null 2>&1; "${QS[@]}" widgetsQuiet false > /dev/null 2>&1; [[ -n $poll ]] && kill "$poll" 2> /dev/null; [[ -n $rec ]] && kill -INT "$rec" 2> /dev/null' EXIT

hyprctl layers -j | jq -r '.[].levels[][] | .address' > "$out/before"
rm -f "$out/rec.mkv" "$out/layers"
wf-recorder -D -r 60 -o "$mon" -c libx264rgb -p qp=0 -p preset=ultrafast -f "$out/rec.mkv" > "$out/rec.log" 2>&1 &
rec=$!
(while :; do printf '%s %s\n' "$(date +%s.%N)" "$(hyprctl layers -j | tr -d '\n')"; sleep 0.012; done) >> "$out/layers" &
poll=$!
for _ in $(seq 50); do [[ -s $out/rec.mkv ]] && break; sleep 0.05; done
sleep 0.3
echo "#open $(date +%s.%N)" >> "$out/layers"
run "$open"
sleep "$hold"
echo "#close $(date +%s.%N)" >> "$out/layers"
run "$close"
sleep 0.8
kill "$poll" 2>/dev/null
kill -INT "$rec" 2>/dev/null
wait "$rec" 2>/dev/null
MOTION_MON=$mon MOTION_TRANSFORM=$mt MOTION_ORIGIN=${MOTION_ORIGIN:-$mx,$my} python3 "$HERE/motion.py" "$out/rec.mkv" "$out/layers" "$out/before" "$mw" "$mh"
