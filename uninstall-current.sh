#!/usr/bin/env bash
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
home=$HOME
backups=$HOME/backups/torus
dry_run=0
while (($#)); do
  case $1 in
    --home) home=$2; shift 2 ;;
    --backups) backups=$2; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

state=${XDG_STATE_HOME:-$home/.local/state}/torus
if [[ -e $state/cutover ]]; then
  echo "HyDE was already moved ($state/cutover exists)" >&2
  sed -n 's/^backup=/backup=/p' "$state/cutover" | head -n 1
  exit 9
fi

newest=$(find "$backups" -mindepth 1 -maxdepth 1 -type d -name '[0-9]*-[0-9]*' 2> /dev/null | sort | tail -n 1)
[[ -n $newest ]] || { echo "no backup in $backups, run sudo backup/backup.sh first" >&2; exit 2; }
stamp=$(basename "$newest")
tarball=$newest/torus-backup-$stamp.tar.zst
if ! (cd "$newest" && sha256sum -c --quiet "torus-backup-$stamp.tar.zst.sha256") > /dev/null 2>&1; then
  echo "newest backup does not verify: $tarball" >&2
  exit 2
fi
made=$(date -d "${stamp:0:4}-${stamp:4:2}-${stamp:6:2} ${stamp:9:2}:${stamp:11:2}:${stamp:13:2}" +%s)
if (($(date +%s) - made > 86400)); then
  echo "newest backup $stamp is older than 24 h, make a fresh one first" >&2
  exit 3
fi
tested=0
for m in "$backups"/*/restore-tested; do
  [[ -f $m ]] || continue
  d=$(dirname "$m")
  want=$(sed -n 's/^tarball_sha256=//p' "$m")
  got=$(cut -d' ' -f1 "$d"/torus-backup-*.tar.zst.sha256 2> /dev/null | head -n 1)
  [[ -n $want && $want == "$got" ]] && tested=1
done
((tested)) || { echo "no backup has passed a VM restore test (vm/restore-test.sh)" >&2; exit 2; }

mapfile -t remove < <(grep -v '^\s*$' "$REPO/packages/remove.txt")
mapfile -t installed < <(pacman -Qq "${remove[@]}" 2> /dev/null || true)
if ((${#installed[@]})) && ! pacman -Rsp --print "${installed[@]}" > /dev/null 2>&1; then
  echo "pacman cannot remove: ${installed[*]} (nothing was changed)" >&2
  exit 4
fi
mapfile -t native < <(grep -v '^\s*$' "$REPO/packages/native.txt")
if ! sudo pacman -Sw --needed --noconfirm "${native[@]}" > /dev/null 2>&1; then
  echo "cannot download the torus packages, run sudo pacman -Syu and reboot, then try again (nothing was changed)" >&2
  exit 4
fi
if command -v sbctl > /dev/null; then
  unsigned=$(sudo sbctl verify 2>&1 | grep 'is not signed' | grep -v ' /boot/grub/' || true)
  if [[ -n $unsigned ]]; then
    printf '%s\n' "$unsigned" >&2
    echo "unsigned EFI files, run sudo sbctl sign-all first (nothing was changed)" >&2
    exit 5
  fi
fi

paths=(HyDE .config/waybar .config/swaync .config/dunst .config/wlogout .config/hyde .local/share/hyde
  .local/share/hypr .local/share/waybar .local/share/wallbash .local/state/hyde .local/lib/hyde .cache/hyde
  .config/systemd/user/hyde-config.service .config/systemd/user/hyde-ipc.service
  .config/uwsm/env-hyprland .config/uwsm/env-hyprland.d/00-hyde.sh .config/uwsm/env.d/00-hyde.sh)
attic=$home/.local/share/torus/attic/$(date +%Y%m%d-%H%M%S)-hyde

act() {
  if ((dry_run)); then echo "+ $*"; else "$@"; fi
}

if ((!dry_run)); then
  mkdir -p "$state"
  echo "backup=$newest" > "$state/cutover"
fi
for unit in hyde-config.service hyde-ipc.service; do
  [[ -e $home/.config/systemd/user/$unit ]] && act systemctl --user disable --now "$unit" > /dev/null 2>&1 || true
done
for p in "${paths[@]}"; do
  [[ -e $home/$p || -L $home/$p ]] || continue
  act mkdir -p "$(dirname "$attic/$p")"
  act mv "$home/$p" "$attic/$p"
done
((${#installed[@]})) && act sudo pacman -Rns --noconfirm "${installed[@]}"
echo "HyDE moved to $attic"
echo "backup=$newest"
