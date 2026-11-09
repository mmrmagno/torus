#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
V=${TORUS_VM_DIR:-$HOME/vms/torus}
name=""
for f in "$V"/*.pid; do [[ -e $f ]] && kill -0 "$(cat "$f")" 2>/dev/null && { name=$(basename "$f" .pid); break; }; done
[[ -n $name ]] || { echo "no VM running" >&2; exit 2; }
qmp="$V/$name.qmp"
env='export LANG=C.UTF-8 WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1);'
vm() { "$here/torus-vm" ssh "$env $1"; }
keys() { python3 "$here/qmp-keys.py" "$qmp" "$1"; sleep 0.7; }
active() { vm 'hyprctl activewindow -j | jq -r .address'; }
open() { vm 'qs -c torus ipc call torus isOpen alttab 2>/dev/null | tail -n 1'; }

vm 'for t in alpha beta gamma; do hyprctl eval "hl.exec_cmd(\"kitty --class alttab-keys --title k-$t\")" > /dev/null; sleep 0.6; done; sleep 3' > /dev/null
fail=0
check() {
  local label=$1 seq=$2 want=$3 before after state
  before=$(active); keys "$seq"; after=$(active); state=$(open)
  local got=same; [[ $before != "$after" ]] && got=switched
  if [[ $state == false && $got == "$want" ]]; then echo "ok   $label"; else echo "FAIL $label (open=$state $got)"; fail=1; if [[ $state == true ]]; then keys "alt+ 20 alt-"; fi; fi
}
for i in 1 2 3; do check "alt released before tab #$i" "alt+ 15 tab+ 15 alt- 10 tab-" switched; done
for i in 1 2 3; do check "zero-gap tap #$i" "alt+ 5 tab+ 0 tab- 0 alt-" switched; done
check "held, one tab" "alt+ 30 tab+ 40 tab- 400 alt-" switched
check "escape cancels" "alt+ 30 tab+ 40 tab- 300 esc+ 30 esc- 100 alt-" same
vm 'hyprctl eval "hl.dispatch(hl.dsp.focus({ window = \"title:k-alpha\" }))"' > /dev/null
keys "alt+ 40 tab+ 40 tab- 400 g+ 30 g- 60 a+ 30 a- 60 m+ 30 m- 400 alt-"
title=$(vm 'hyprctl activewindow -j | jq -r .title')
if [[ $title == k-gamma && $(open) == false ]]; then echo "ok   typing filters to gamma"; else echo "FAIL typing filter (focused $title)"; fail=1; fi
vm 'hyprctl clients -j | jq -r ".[] | select(.class == \"alttab-keys\") | .pid" | xargs -r kill' > /dev/null
exit $fail
