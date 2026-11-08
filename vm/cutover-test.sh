#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
VM=$HERE/torus-vm
V=${TORUS_VM_DIR:-$HOME/vms/torus}
stamp=$(date +%Y%m%d-%H%M%S)
shots=$V/shots/cutover-$stamp
log=$V/logs/cutover-$stamp.log
mkdir -p "$shots" "$V/logs"
passed=0 total=0

say() { echo "cutover-test: $*" | tee -a "$log"; }
check() {
  local name=$1 detail=$2
  shift 2
  total=$((total + 1))
  if "$@" >> "$log" 2>&1; then
    passed=$((passed + 1)); say "$name ok $detail"
  else
    say "$name FAIL $detail"
  fi
}

cleanup() { "$VM" down cut > /dev/null 2>&1 || true; "$VM" rm cut > /dev/null 2>&1 || true; }
trap cleanup EXIT

G='export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 LANG=C.UTF-8 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr 2>/dev/null | head -1); export PATH=$HOME/.local/bin:$PATH;'
gssh() { "$VM" ssh "$G $1"; }
pw=$(printf %q "$(cat "$V/password")")

boot_and_wait() {
  local tag=$1 i
  (for i in $(seq -w 1 90); do timeout 3 gvnccapture -q 127.0.0.1:5 "$shots/boot-$tag-$i.png" 2> /dev/null || true; sleep 0.4; done) &
  local cap=$!
  "$VM" ssh 'sudo systemctl reboot' 2> /dev/null || true
  wait "$cap"
  for i in $(seq 60); do gssh 'ls /run/user/1000/hypr/*/hyprland.lock' > /dev/null 2>&1 && break; sleep 5; done
  sleep 20
}

secure_boot() {
  gssh 'sudo sbctl status | grep -q "Secure Boot:.*Enabled" && [[ $(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c | awk "{print \$NF}") == 1 ]]'
}

snapshot() {
  gssh 'sha256sum /etc/default/grub /etc/mkinitcpio.conf; ls /etc/sddm.conf.d; grep -q "^HOOKS=.*plymouth" /etc/mkinitcpio.conf && plymouth-set-default-theme; true' > "$shots/$1-system.txt"
  gssh 'pacman -Qq | sort' > "$shots/$1-packages.txt"
}

cleanup
"$VM" up cut --from hyde
say "fixtures"
"$VM" ssh 'printf "[Autologin]\nUser=mmr\nSession=hyprland-uwsm\n" | sudo tee /etc/sddm.conf.d/zz-vm-autologin.conf > /dev/null && sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target > /dev/null 2>&1 && sudo pacman -Syu --noconfirm > /dev/null 2>&1 && sudo pacman -S --needed --noconfirm mpv mpv-mpris ffmpeg wtype socat > /dev/null 2>&1' >> "$log" 2>&1
"$VM" push "$REPO" > /dev/null
"$VM" ssh 'grep -o "\$HOME/[^\"]*" ~/.config/user-dirs.dirs 2>/dev/null | sed "s|\$HOME|$HOME|" | xargs -r -d "\n" mkdir -p'
say "updated, rebooting like the checklist says"
boot_and_wait update

say "fresh backup of the HyDE state"
"$VM" ssh 'sudo ~/torus/backup/backup.sh' >> "$log" 2>&1
"$VM" ssh 'd=$(ls -d ~/backups/torus/*/ | sort | tail -1); printf "tarball_sha256=%s\ntested=vm-fixture\n" "$(cut -d" " -f1 "$d"/torus-backup-*.tar.zst.sha256)" > "$d/restore-tested"'
snapshot hyde-before

say "cutover"
check cutover-exit "cutover.sh exits 0" gssh 'cd ~/torus && ./cutover.sh'
boot_and_wait torus
gssh 'hyprctl eval "hl.monitor({ output = \"Virtual-1\", mode = \"1920x1080@60\", position = \"0x0\", scale = 1 })" > /dev/null; hyprctl output create headless SIDE > /dev/null; hyprctl eval "hl.monitor({ output = \"SIDE\", mode = \"1920x1080\", position = \"1920x0\", scale = 1, transform = 3 })" > /dev/null' || true
sleep 5
check torus-secure-boot "Secure Boot on after cutover" secure_boot
check torus-shell "quickshell and torus-shell.service run" gssh 'pgrep -x qs && systemctl --user is-active torus-shell.service'
check torus-no-hyde "no waybar, swaync or hyde-config" gssh '! pgrep -x waybar && ! pgrep -x swaync && ! systemctl --user is-active --quiet hyde-config.service'
check torus-state "cutover state recorded" gssh 'grep -q "^backup=" ~/.local/state/torus/cutover'
check torus-config "Hyprland reads the torus config" gssh '! tr "\\0" "\\n" < /proc/$(pgrep -x Hyprland)/environ | grep -q ^HYPRLAND_CONFIG= && [[ -z $(hyprctl configerrors | tr -d "[:space:]") ]]'
gssh 'grim /tmp/shot.png' && "$VM" scp-from /tmp/shot.png "$shots/torus-desktop.png" || true
timeout 2400 "$VM" ssh "$G LOCK_PW=$pw ~/torus/vm/parity.sh all < /dev/null" > "$shots/parity.txt" 2>&1 || true
cat "$shots/parity.txt" >> "$log"
check torus-parity "$(tail -n 1 "$shots/parity.txt")" grep -qE '^parity: ([0-9]+)/\1$' "$shots/parity.txt"

say "rollback"
check rollback-exit "rollback.sh exits 0" gssh 'cd ~/torus && ./rollback.sh'
boot_and_wait hyde
check hyde-secure-boot "Secure Boot on after rollback" secure_boot
check hyde-verify "restore.sh --verify-only" gssh 'sudo ~/torus/backup/restore.sh "$(ls -d ~/backups/torus/*/ | sort | tail -1)" --verify-only'
snapshot hyde-after
check hyde-system "grub, mkinitcpio, sddm.conf.d and plymouth theme as before" cmp "$shots/hyde-before-system.txt" "$shots/hyde-after-system.txt"
check hyde-packages "every HyDE package back" bash -c "LC_ALL=C comm -23 <(LC_ALL=C sort '$shots/hyde-before-packages.txt') <(LC_ALL=C sort '$shots/hyde-after-packages.txt') > '$shots/missing-after-rollback.txt'; [[ ! -s '$shots/missing-after-rollback.txt' ]]"
check hyde-session "HyDE session (waybar) and no quickshell" gssh 'pgrep -x waybar && ! pgrep -x qs'
check hyde-no-state "cutover state removed" gssh '[[ ! -e ~/.local/state/torus/cutover ]]'
gssh 'grim /tmp/shot.png' && "$VM" scp-from /tmp/shot.png "$shots/hyde-desktop.png" || true

say "done $passed/$total, shots in $shots"
((passed == total))
