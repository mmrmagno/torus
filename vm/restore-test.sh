#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
VM=$HERE/torus-vm
V=${TORUS_VM_DIR:-$HOME/vms/torus}

[[ $# -eq 1 ]] || { echo "usage: $0 <backup-dir>" >&2; exit 1; }
dir=$(cd "$1" && pwd)
tarball=$(find "$dir" -maxdepth 1 -name 'torus-backup-*.tar.zst' | head -1)
[[ -n $tarball ]] || { echo "no tarball in $dir" >&2; exit 1; }
stamp=$(date +%Y%m%d-%H%M%S)
log=$V/logs/restore-$stamp.log
shots=$V/shots/restore-$stamp
mkdir -p "$V/logs" "$shots"

cleanup() {
  "$VM" down restore || true
}
trap cleanup EXIT

"$VM" up restore --from base
"$VM" ssh 'mkdir -p ~/restore'
"$VM" scp-to "$tarball" restore/
"$VM" scp-to "$tarball.sha256" restore/
"$VM" scp-to "$HERE/../backup/restore.sh" restore/

rc=0
"$VM" ssh 'sudo ~/restore/restore.sh ~/restore' > "$log" 2>&1 || rc=$?
echo "restore exit: $rc" | tee -a "$log"
"$VM" scp-from restore/missing-packages.txt "$shots/" 2>/dev/null || true
case $rc in
  0|7) ;;
  *) echo "restore failed, see $log" >&2; exit 1 ;;
esac

"$VM" ssh 'grep -o "\$HOME/[^\"]*" ~/.config/user-dirs.dirs 2>/dev/null | sed "s|\$HOME|$HOME|" | xargs -r -d "\n" mkdir -p'
"$VM" reboot
sleep 20
"$VM" shot "$shots/sddm.png"

"$VM" ssh 'sudo ~/restore/restore.sh ~/restore --verify-only' | tee -a "$log"

want=$(tar --zstd --numeric-owner -tvf "$tarball" home/ 2>/dev/null | awk '$6 == "home/" && !f {print $1, $2; f = 1}')
got=$("$VM" ssh 'stat -c "%A %u/%g" ~')
echo "home dir: backup [$want] restored [$got]" | tee -a "$log"
[[ $want == "$got" ]] || { echo "home dir owner or mode changed by restore" >&2; exit 1; }

tar -xOf "$tarball" meta/units-system.txt > "$shots/units-system.txt"
bad=0
while read -r u; do
  [[ -n $u ]] || continue
  case $u in *@.service|*@.*) continue ;; esac
  state=$("$VM" ssh "systemctl is-enabled $u" </dev/null 2>/dev/null || true)
  [[ $state == enabled* || $state == alias || $state == static ]] || { echo "unit not enabled: $u ($state)" | tee -a "$log"; bad=1; }
done < "$shots/units-system.txt"
((bad == 0)) || { echo "unit check failed" >&2; exit 1; }

"$VM" ssh 'sudo rm -rf ~/restore'
"$VM" down restore
"$VM" freeze restore hyde
"$VM" rm restore
printf 'tarball_sha256=%s\ntested=%s\nlog=%s\n' "$(cut -d' ' -f1 "$tarball.sha256")" "$stamp" "$log" > "$dir/restore-tested"

"$VM" up hydeshot --from hyde
"$VM" ssh 'printf "[Autologin]\nUser=mmr\nSession=hyprland-uwsm\n" | sudo tee /etc/sddm.conf.d/zz-vm-autologin.conf >/dev/null'
"$VM" reboot
t=0
until "$VM" ssh 'ls /run/user/1000/hypr/*/hyprland.lock' >/dev/null 2>&1; do
  sleep 10; t=$((t + 10)); ((t < 300)) || { echo "Hyprland did not start" >&2; break; }
done
sleep 30
"$VM" ssh 'pkill -x gcr-prompter' || true
sleep 5
if "$VM" ssh 'pgrep -x waybar' >/dev/null; then echo "hyde session: waybar running" | tee -a "$log"; else echo "hyde session: waybar NOT running" | tee -a "$log"; fi
for o in $("$VM" ssh 'export XDG_RUNTIME_DIR=/run/user/1000 HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr | head -1); hyprctl monitors -j | jq -r ".[].name"'); do
  "$VM" ssh "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 grim -o $o /tmp/$o.png" && "$VM" scp-from "/tmp/$o.png" "$shots/hyde-$o.png"
done
"$VM" down hydeshot
"$VM" rm hydeshot
trap - EXIT
echo "restore proven: $dir/restore-tested, screenshots in $shots"
