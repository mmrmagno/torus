#!/usr/bin/env bash
set -euo pipefail

dir="" home="" root="" torus="" files_only=0 dry_run=0 verify_only=0
while (($#)); do
  case $1 in
    --home) home=$2; shift 2 ;;
    --root) root=$2; shift 2 ;;
    --torus) torus=$2; shift 2 ;;
    --files-only) files_only=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --verify-only) verify_only=1; shift ;;
    -*) echo "unknown option: $1" >&2; exit 1 ;;
    *) dir=$1; shift ;;
  esac
done
[[ -n $dir ]] || { echo "usage: $0 <backup-dir> [--home DIR] [--root DIR] [--torus DIR] [--files-only] [--dry-run] [--verify-only]" >&2; exit 1; }
dir=$(cd "$dir" && pwd)

if [[ -z $home || -z $root ]] && [[ $EUID -ne 0 || -z ${SUDO_USER:-} || ${SUDO_USER:-} == root ]]; then
  echo "run with sudo from your own account: sudo $0 $dir" >&2
  exit 2
fi
user=${SUDO_USER:-$(id -un)}
[[ -n $home ]] || home=$(getent passwd "$user" | cut -d: -f6)
[[ -n $root ]] || root=/
root=${root%/}
[[ -n $torus ]] || torus=${TORUS_DIR:-$home/dev/priv/torus}

tarball=$(find "$dir" -maxdepth 1 -name 'torus-backup-*.tar.zst' | head -1)
[[ -n $tarball ]] || { echo "no tarball in $dir" >&2; exit 4; }
U=$dir/.unpack
grant=$root/etc/sudoers.d/zz-torus-restore
cleanup() { rm -rf "$U"; rm -f "$grant"; }
trap cleanup EXIT

if ! (cd "$dir" && sha256sum -c --quiet "${tarball##*/}.sha256"); then
  echo "tarball checksum mismatch, nothing restored" >&2
  exit 4
fi
rm -rf "$U"
mkdir -p "$U"
if ! tar --zstd --numeric-owner -xpf "$tarball" -C "$U" 2>/dev/null || ! (cd "$U" && sha256sum -c --quiet MANIFEST.sha256); then
  echo "backup contents do not match MANIFEST.sha256, nothing restored" >&2
  exit 4
fi

identity=(etc/fstab etc/crypttab etc/hostname etc/machine-id etc/passwd etc/group etc/shadow etc/gshadow etc/subuid etc/subgid boot/grub/grub.cfg)
same_machine=0
if [[ "$(cat "$U/meta/machine-id" 2>/dev/null)" == "$(cat "$root/etc/machine-id" 2>/dev/null)" ]]; then
  same_machine=1
fi
: > "$U/skipped.txt"
if ((!same_machine)); then
  for f in "${identity[@]}"; do
    if [[ -e $U/system/$f ]]; then
      echo "system/$f" >> "$U/skipped.txt"
      echo "skipped, other machine: system/$f"
      rm -f "$U/system/$f"
    fi
  done
fi

verify_live() {
  local live=$U/MANIFEST.live bad
  awk -v h="$home" -v r="$root" -v skipfile="$U/skipped.txt" '
    BEGIN { while ((getline l < skipfile) > 0) skip[l] = 1 }
    { esc = substr($0,1,1) == "\\"; line = esc ? substr($0,2) : $0
      hash = substr(line,1,64); path = substr(line,67)
      if (path in skip) next
      if (path ~ /^home\//) p = h "/" substr(path,6)
      else if (path ~ /^system\//) p = r "/" substr(path,8)
      else next
      print (esc ? "\\" : "") hash "  " p }' "$U/MANIFEST.sha256" > "$live"
  if bad=$(sha256sum -c --quiet "$live" 2>&1); then
    echo "restore verified: $(wc -l < "$live") files"
  else
    echo "restore mismatch:" >&2
    printf '%s\n' "$bad" | sed -e "s|^$home/|home/|" -e "s|^$root/|system/|" >&2
    exit 5
  fi
}

if ((verify_only)); then
  verify_live
  exit 0
fi

run() {
  echo "+ $*"
  ((dry_run)) || "$@"
}

as_user() {
  if [[ $EUID -eq 0 && $user != root ]]; then
    run sudo -u "$user" XDG_RUNTIME_DIR="/run/user/$(id -u "$user")" "$@"
  else
    run "$@"
  fi
}

install_each() {
  local mgr=$1; shift
  local p
  for p in "$@"; do
    if [[ $mgr == yay ]]; then
      as_user yay -S --needed --noconfirm --nosudoloop "$p" || echo "$p" >> "$missing"
    else
      run pacman -S --needed --noconfirm "$p" || echo "$p" >> "$missing"
    fi
  done
}

missing=$dir/missing-packages.txt
((dry_run)) || : > "$missing"
mkinit_before=$(sha256sum "$root/etc/mkinitcpio.conf" 2>/dev/null | cut -d' ' -f1 || true)

if [[ -d $home ]]; then
  if ((dry_run)); then
    echo "+ remove links into $torus"
  else
    find "$home" -xdev -type l -lname "$torus/*" -print0 2>/dev/null | xargs -0 -r rm -f
  fi
fi
keep=$home/.local/share/torus/attic/$(date +%Y%m%d-%H%M%S)-replaced
as_user mkdir -p "$keep"
run rsync -a --checksum --backup --backup-dir="$keep" "$U/home/" "$home/"
if ((!dry_run)); then
  if rmdir "$keep" 2> /dev/null; then
    :
  else
    [[ $EUID -eq 0 ]] && chown -R "$user": "$keep"
    echo "replaced files kept in $keep"
  fi
fi
run rsync -a --ignore-times "$U/system/" "$root/"
while IFS=$'\t' read -r path target; do
  case $path in
    home/*) live=$home/${path#home/} ;;
    system/*) live=$root/${path#system/} ;;
    *) continue ;;
  esac
  ((dry_run)) || mkdir -p "$(dirname "$live")"
  run ln -sfn "$target" "$live" > /dev/null
done < "$U/LINKS.txt"

if ((files_only)); then
  verify_live
  exit 0
fi

M=$U/meta
if grep -q '^\[chaotic-aur\]' "$root/etc/pacman.conf" 2>/dev/null && ! pacman -Qq chaotic-keyring >/dev/null 2>&1; then
  boot_conf=$U/pacman.nochaotic.conf
  awk '/^\[chaotic-aur\]/ {skip = 1; next} /^\[/ {skip = 0} !skip' "$root/etc/pacman.conf" > "$boot_conf"
  run pacman-key --config "$boot_conf" --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
  run pacman-key --config "$boot_conf" --lsign-key 3056513887B78AEB
  run pacman --config "$boot_conf" -U --noconfirm https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst
  run pacman-key --populate chaotic
fi

mapfile -t native < <(grep -v '^\s*$' "$M/pkg-native.txt" 2>/dev/null || true)
if ((${#native[@]})); then
  if ! run pacman -Syu --needed --noconfirm "${native[@]}"; then
    run pacman -Syu --noconfirm || true
    mapfile -t avail < <(comm -12 <(printf '%s\n' "${native[@]}" | sort -u) <(pacman -Slq | sort -u))
    comm -23 <(printf '%s\n' "${native[@]}" | sort -u) <(pacman -Slq | sort -u) >> "$missing"
    if ((${#avail[@]})); then
      run pacman -S --needed --noconfirm "${avail[@]}" || install_each pacman "${avail[@]}"
    fi
  fi
fi
mapfile -t foreign < <(grep -v -e '^\s*$' -e '-debug$' "$M/pkg-foreign.txt" 2>/dev/null || true)
if ((${#foreign[@]})); then
  # yay runs as the user and asks sudo for pacman; nobody can type a password here
  if ((!dry_run)) && [[ $user != root ]]; then
    mkdir -p "$(dirname "$grant")"
    printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$user" > "$grant"
    chmod 440 "$grant"
  fi
  as_user yay -S --needed --noconfirm --nosudoloop "${foreign[@]}" || install_each yay "${foreign[@]}"
  rm -f "$grant"
fi
mapfile -t flatpaks < <(grep -v '^\s*$' "$M/flatpak.txt" 2>/dev/null || true)
if ((${#flatpaks[@]})); then
  run flatpak install -y --noninteractive flathub "${flatpaks[@]}" || echo "warning: some flatpaks failed" >&2
fi

failed_units=()
while read -r u; do
  [[ -n $u ]] || continue
  run systemctl enable "$u" || failed_units+=("$u")
done < "$M/units-system.txt"
while read -r u; do
  [[ -n $u ]] && { as_user systemctl --user enable "$u" || echo "warning: user enable $u failed" >&2; }
done < "$M/units-user.txt"
while read -r u; do
  [[ -n $u ]] && { as_user systemctl --user mask "$u" || echo "warning: user mask $u failed" >&2; }
done < "$M/masked-user.txt"
if [[ -s $M/dconf.ini ]]; then
  if ((dry_run)); then echo "+ dconf load / < meta/dconf.ini"; else as_user dconf load / < "$M/dconf.ini" > /dev/null || echo "warning: dconf load failed" >&2; fi
fi

((same_machine)) || run grub-mkconfig -o "$root/boot/grub/grub.cfg"
mkinit_after=$(sha256sum "$root/etc/mkinitcpio.conf" 2>/dev/null | cut -d' ' -f1 || true)
[[ $mkinit_before == "$mkinit_after" ]] || run mkinitcpio -P
if command -v sbctl >/dev/null; then
  run sbctl sign-all
  if ((!dry_run)); then
    verify_out=$(sbctl verify 2>&1 || true)
    unsigned=$(grep 'is not signed' <<<"$verify_out" | grep -v ' /boot/grub/' || true)
    if [[ -n $unsigned ]]; then
      printf '%s\n' "$unsigned" >&2
      echo "unsigned files under /boot, fix before rebooting" >&2
      exit 6
    fi
  fi
fi

((dry_run)) && exit 0
verify_live
if [[ -s $missing ]]; then
  echo "packages that could not be installed:" >&2
  cat "$missing" >&2
fi
if ((${#failed_units[@]})); then
  echo "system units that could not be enabled: ${failed_units[*]}" >&2
  exit 8
fi
[[ -s $missing ]] && exit 7
exit 0
