#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
VM=$HERE/torus-vm
V=${TORUS_VM_DIR:-$HOME/vms/torus}
stamp=$(date +%Y%m%d-%H%M%S)
shots=$V/shots/rice-$stamp
log=$V/logs/rice-$stamp.log
mkdir -p "$shots/boot" "$V/logs"

say() { echo "rice-test: $*" | tee -a "$log"; }

cleanup() { "$VM" down rice || true; }
trap cleanup EXIT

G='export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 LANG=C.UTF-8 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr 2>/dev/null | head -1); export PATH=$HOME/.local/bin:$PATH;'

gssh() { "$VM" ssh "$G $1"; }

grab() {
  local name=$1 out=${2:-}
  gssh "grim ${out:+-o $out} /tmp/shot.png" && "$VM" scp-from /tmp/shot.png "$shots/$name.png"
}

qs_call() { gssh "qs -c torus ipc call torus $*" > /dev/null; }

"$VM" rm rice 2> /dev/null || true
"$VM" up rice --from base
say "installing yay"
"$VM" ssh 'sudo pacman -S --needed --noconfirm git base-devel > /dev/null && rm -rf /tmp/yay-bin && git clone -q https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && cd /tmp/yay-bin && makepkg -si --noconfirm > /dev/null 2>&1' >> "$log" 2>&1
"$VM" push "$REPO" > /dev/null
say "install.sh (packages, links, setup)"
"$VM" ssh 'export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; ~/torus/install.sh' >> "$log" 2>&1
say "install.sh --system"
"$VM" ssh 'sudo ~/torus/install.sh --system' >> "$log" 2>&1
"$VM" ssh 'mkdir -p ~/.config/uwsm && echo "export TORUS_VM=1" > ~/.config/uwsm/env-hyprland && sudo systemctl enable sddm > /dev/null 2>&1 && printf "source ~/.config/zsh/conf.d/torus.zsh\n" > ~/.zshrc && sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target > /dev/null 2>&1'

say "reboot 1: boot chain capture"
(for i in $(seq -w 1 110); do timeout 3 gvnccapture -q 127.0.0.1:5 "$shots/boot/b$i.png" 2> /dev/null || true; sleep 0.4; done) &
cap=$!
"$VM" ssh 'sudo systemctl reboot' 2> /dev/null || true
wait "$cap"
"$VM" ssh 'true' 2> /dev/null || sleep 20
"$VM" ssh 'sudo sbctl status | grep -E "Secure Boot"' | tee -a "$log"

say "reboot 2: session"
"$VM" ssh 'printf "[Autologin]\nUser=mmr\nSession=hyprland-uwsm\n" | sudo tee /etc/sddm.conf.d/zz-vm-autologin.conf > /dev/null'
"$VM" reboot
for _ in $(seq 60); do gssh 'hyprctl monitors -j > /dev/null 2>&1' && break; sleep 3; done
sleep 15
gssh 'hyprctl output create headless SIDE > /dev/null; hyprctl eval "hl.monitor({ output = \"SIDE\", mode = \"1920x1080\", position = \"1280x0\", scale = 1, transform = 3 })" > /dev/null'
sleep 5

say "parity"
gssh '~/torus/vm/parity.sh all' 2>&1 | tee -a "$log" | tee "$shots/parity.txt" || true

say "screenshots"
gssh 'hyprctl clients -j | jq -r ".[].pid" | xargs -r kill; hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"Virtual-1\" }))" > /dev/null'
sleep 2
grab desktop-main Virtual-1
grab desktop-portrait SIDE
qs_call dashboardToggle; sleep 1.5; grab dashboard Virtual-1; qs_call dashboardToggle
gssh 'notify-send -a torus "marc @ os" "notifications live in the shell now"'; sleep 1; grab notification Virtual-1
qs_call centerToggle; sleep 1; grab center Virtual-1; qs_call centerToggle
qs_call cheatSheetToggle; sleep 1.5; grab cheatsheet Virtual-1; qs_call cheatSheetToggle
qs_call logoutToggle; sleep 1; grab logout Virtual-1; qs_call logoutToggle
gssh 'hyprctl eval "hl.exec_cmd(\"torus-menu drun\")" > /dev/null'; sleep 1.5; grab menu Virtual-1; gssh 'pkill -x rofi || true'
gssh 'hyprctl eval "hl.exec_cmd(\"kitty --title fastfetch -e sh -c \\\"fastfetch; exec zsh\\\"\")" > /dev/null; sleep 1; hyprctl eval "hl.exec_cmd(\"kitty -e btop\")" > /dev/null; sleep 1; hyprctl eval "hl.exec_cmd(\"dolphin\")" > /dev/null'
sleep 4
grab apps Virtual-1
qs_call overviewToggle; sleep 1.5; grab overview Virtual-1; qs_call overviewToggle
qs_call altTab next; sleep 1; grab alttab Virtual-1; qs_call altTab apply
gssh 'torus-lock' &
sleep 4
"$VM" shot "$shots/lock.png" > /dev/null
gssh 'pkill -USR1 -x hyprlock || true'
sleep 4

say "accent blue"
gssh 'torus accent blue > /dev/null 2>&1'
sleep 3
grab accent-blue Virtual-1
gssh 'torus accent mauve > /dev/null 2>&1'

"$VM" down rice
trap - EXIT
passed=$(grep -c ': ok' "$shots/parity.txt" || true)
total=$(grep -cE ': (ok|FAIL)' "$shots/parity.txt" || true)
say "done: parity $passed/$total, screenshots in $shots"
((passed == total && total > 0))
