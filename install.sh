#!/usr/bin/env bash
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
home=$HOME no_packages=0 dry_run=0 system=0 root="" accent=""

while (($#)); do
  case $1 in
    --home) home=$2; shift 2 ;;
    --no-packages) no_packages=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --system) system=1; shift ;;
    --root) root=$2; shift 2 ;;
    --accent) accent=$2; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

system_install() {
  local R=${root:-/}
  R=${R%/}
  local user=${SUDO_USER:-$(id -un)}
  local uhome
  uhome=$(getent passwd "$user" | cut -d: -f6)
  [[ -n $accent ]] || accent=$(cat "$uhome/.local/state/torus/accent" 2> /dev/null || echo mauve)
  local missing=() c
  for c in deno magick plymouth-set-default-theme grub-mkconfig mkinitcpio; do
    command -v "$c" > /dev/null || missing+=("$c")
  done
  [[ -f $R/etc/default/grub ]] || missing+=("$R/etc/default/grub")
  [[ -f $R/etc/mkinitcpio.conf ]] || missing+=("$R/etc/mkinitcpio.conf")
  if ((${#missing[@]})); then
    echo "torus: missing before any change: ${missing[*]}. Run ./install.sh as your user first (it installs packages), then sudo ./install.sh --system" >&2
    exit 3
  fi
  local stamp attic tmp f i
  stamp=$(date +%Y%m%d-%H%M%S)
  attic=$R/var/lib/torus/attic/$stamp
  for f in etc/default/grub etc/mkinitcpio.conf etc/sddm.conf.d/zz-torus.conf; do
    [[ -f $R/$f ]] && install -D -m 644 "$R/$f" "$attic/$f"
  done
  while IFS= read -r -d '' f; do
    install -D -m 644 "$REPO/system/$f" "$R/$f"
  done < <(cd "$REPO/system" && find . -type f -printf '%P\0')

  tmp=$(mktemp -d)
  chmod 755 "$tmp"
  [[ $EUID -eq 0 && $user != root ]] && chown "$user" "$tmp"
  local as=()
  [[ $EUID -eq 0 && $user != root ]] && as=(sudo -u "$user")
  local render=("${as[@]}" deno run --quiet --allow-read --allow-write --allow-run "$REPO/donut/render-frames.ts")
  "${render[@]}" "$tmp/ply" "${TORUS_PLY_FRAMES:-90}" 360 transparent > /dev/null
  "${render[@]}" "$tmp/grub" 1 320 transparent > /dev/null
  "${render[@]}" "$tmp/sddm" 1 360 transparent > /dev/null
  for i in $(seq 0 $((${TORUS_PLY_FRAMES:-90} - 1))); do
    install -D -m 644 "$tmp/ply/frame-$(printf %04d "$i").png" "$R/usr/share/plymouth/themes/marc-os/frame-$i.png"
  done
  magick "$tmp/grub/frame-0000.png" -depth 8 "PNG32:$tmp/grub/donut.png"
  install -D -m 644 "$tmp/grub/donut.png" "$R/boot/grub/themes/marc-os/donut.png"
  mkdir -p "$R/usr/share/sddm/themes"
  magick -size 1920x1080 xc:'#1e1e2e' "$tmp/sddm/frame-0000.png" -gravity north -geometry +0+40 -composite "$R/usr/share/sddm/themes/torus-background.png"
  rm -rf "$tmp"

  if [[ -d $R/usr/share/sddm/themes/catppuccin-mocha-$accent ]]; then
    mkdir -p "$R/etc/sddm.conf.d"
    printf '[Theme]\nCurrent=catppuccin-mocha-%s\n' "$accent" > "$R/etc/sddm.conf.d/zz-torus.conf"
    printf '[General]\nCustomBackground="true"\nBackground="/usr/share/sddm/themes/torus-background.png"\nFont="Inter"\nFontSize=10\nClockEnabled="true"\n' > "$R/usr/share/sddm/themes/catppuccin-mocha-$accent/theme.conf.user"
  else
    echo "torus: sddm theme catppuccin-mocha-$accent not installed, sddm theme left as it was" >&2
  fi

  local grub=$R/etc/default/grub
  if grep -q '^GRUB_THEME=' "$grub"; then
    sed -i 's|^GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/marc-os/theme.txt"|' "$grub"
  else
    echo 'GRUB_THEME="/boot/grub/themes/marc-os/theme.txt"' >> "$grub"
  fi
  grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\bsplash\b' "$grub" || sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 splash"/' "$grub"
  local mk=$R/etc/mkinitcpio.conf
  if ! grep -qE '^HOOKS=\([^)]*\bplymouth\b' "$mk"; then
    if grep -qE '^HOOKS=\([^)]*\bsystemd\b' "$mk"; then
      sed -i -E 's/^(HOOKS=\([^)]*\bsystemd\b)/\1 plymouth/' "$mk"
    else
      sed -i -E 's/^(HOOKS=\([^)]*\budev\b)/\1 plymouth/' "$mk"
    fi
  fi

  plymouth-set-default-theme marc-os
  grub-mkconfig -o "$R/boot/grub/grub.cfg"
  mkinitcpio -P
  if command -v sbctl > /dev/null; then
    sbctl sign-all
    local unsigned
    unsigned=$(sbctl verify 2>&1 | grep 'is not signed' | grep -v ' /boot/grub/' || true)
    if [[ -n $unsigned ]]; then
      printf '%s\n' "$unsigned" >&2
      echo "torus: unsigned files under /boot, do not reboot until fixed" >&2
      exit 6
    fi
  fi
  echo "torus: system theming done (accent $accent), original files in $attic"
}

if ((system)); then
  if [[ -z $root ]] && [[ $EUID -ne 0 || -z ${SUDO_USER:-} ]]; then
    echo "run with sudo: sudo $0 --system" >&2
    exit 2
  fi
  system_install
  exit 0
fi

[[ $EUID -ne 0 ]] || { echo "run as your own user; system files go through: sudo $0 --system" >&2; exit 2; }

stamp=$(date +%Y%m%d-%H%M%S)
attic=$home/.local/share/torus/attic/$stamp
skip=(.config/hypr/monitors.lua)
linked=0 kept=0 moved=0

act() {
  if ((dry_run)); then
    echo "+ $*"
  else
    "$@"
  fi
}

while IFS= read -r -d '' src; do
  rel=${src#"$REPO/home/"}
  [[ " ${skip[*]} " == *" $rel "* ]] && continue
  dst=$home/$rel
  if [[ -L $dst && $(readlink "$dst") == "$src" ]]; then
    kept=$((kept + 1))
    continue
  fi
  if [[ -e $dst || -L $dst ]]; then
    act mkdir -p "$(dirname "$attic/$rel")"
    act mv "$dst" "$attic/$rel"
    moved=$((moved + 1))
  fi
  act mkdir -p "$(dirname "$dst")"
  act ln -s "$src" "$dst"
  linked=$((linked + 1))
done < <(find "$REPO/home" \( -type f -o -type l \) -print0 | sort -z)

echo "torus: linked $linked, kept $kept, moved $moved"

if ((!no_packages)); then
  mapfile -t native < <(grep -v '^\s*$' "$REPO/packages/native.txt")
  mapfile -t aur < <(grep -v '^\s*$' "$REPO/packages/aur.txt")
  ((${#native[@]})) && act sudo pacman -S --needed --noconfirm "${native[@]}"
  ((${#aur[@]})) && act yay -S --needed --noconfirm "${aur[@]}"
fi
if ((!dry_run)) && [[ $home == "$HOME" ]]; then
  "$REPO/home/.local/bin/torus" setup
fi
exit 0
