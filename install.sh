#!/usr/bin/env bash
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
home=$HOME no_packages=0 dry_run=0 system=0 undo=0 root="" accent="" flavour=""

while (($#)); do
  case $1 in
    --home) home=$2; shift 2 ;;
    --no-packages) no_packages=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --system) system=1; shift ;;
    --undo) undo=1; shift ;;
    --root) root=$2; shift 2 ;;
    --accent) accent=$2; shift 2 ;;
    --flavour) flavour=$2; shift 2 ;;
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
  [[ -n $flavour ]] || flavour=$(cat "$uhome/.local/state/torus/flavour" 2> /dev/null || echo mocha)
  [[ $flavour =~ ^[a-z]+$ && -f $REPO/theme/$flavour.json ]] || { echo "torus: unknown flavour: $flavour" >&2; exit 2; }
  local pal=$REPO/theme/$flavour.json
  local missing=() c
  for c in deno magick plymouth-set-default-theme grub-mkconfig mkinitcpio; do
    command -v "$c" > /dev/null || missing+=("$c")
  done
  local qsb
  qsb=$(command -v qsb || echo /usr/lib/qt6/bin/qsb)
  [[ -x $qsb ]] || missing+=("qsb (qt6-shadertools)")
  [[ -f $R/etc/default/grub ]] || missing+=("$R/etc/default/grub")
  [[ -f $R/etc/mkinitcpio.conf ]] || missing+=("$R/etc/mkinitcpio.conf")
  if ((${#missing[@]})); then
    echo "torus: missing before any change: ${missing[*]}. Run ./install.sh as your user first (it installs packages), then sudo ./install.sh --system" >&2
    exit 3
  fi
  local stamp attic tmp f i
  local O=$R/var/lib/torus/original list=$R/var/lib/torus/installed.txt
  local sddm_user=usr/share/sddm/themes/catppuccin-mocha-$accent/theme.conf.user
  if [[ ! -d $O ]]; then
    mkdir -p "$O"
    : > "$O/absent.txt"
    for f in etc/default/grub etc/mkinitcpio.conf etc/sddm.conf.d/zz-torus.conf "$sddm_user"; do
      if [[ -f $R/$f ]]; then install -D -m 644 "$R/$f" "$O/$f"; else echo "$f" >> "$O/absent.txt"; fi
    done
    plymouth-set-default-theme 2> /dev/null > "$O/plymouth-theme" || true
  fi
  mkdir -p "$(dirname "$list")"
  touch "$list"
  stamp=$(date +%Y%m%d-%H%M%S)
  attic=$R/var/lib/torus/attic/$stamp
  for f in etc/default/grub etc/mkinitcpio.conf etc/sddm.conf.d/zz-torus.conf; do
    [[ -f $R/$f ]] && install -D -m 644 "$R/$f" "$attic/$f"
  done
  while IFS= read -r -d '' f; do
    install -D -m 644 "$REPO/system/$f" "$R/$f"
    echo "$f" >> "$list"
  done < <(cd "$REPO/system" && find . -type f -printf '%P\0')

  tmp=$(mktemp -d)
  chmod 755 "$tmp"
  [[ $EUID -eq 0 && $user != root ]] && chown "$user" "$tmp"
  local as=()
  [[ $EUID -eq 0 && $user != root ]] && as=(sudo -u "$user")
  local render=("${as[@]}" env TORUS_PALETTE="$pal" deno run --quiet --allow-read --allow-write --allow-run --allow-env "$REPO/donut/render-frames.ts")
  "${render[@]}" "$tmp/ply" "${TORUS_PLY_FRAMES:-90}" 360 transparent > /dev/null
  "${render[@]}" "$tmp/grub" 1 320 transparent > /dev/null
  "${render[@]}" "$tmp/sddm" 1 360 transparent > /dev/null
  for i in $(seq 0 $((${TORUS_PLY_FRAMES:-90} - 1))); do
    install -D -m 644 "$tmp/ply/frame-$(printf %04d "$i").png" "$R/usr/share/plymouth/themes/marc-os/frame-$i.png"
    echo "usr/share/plymouth/themes/marc-os/frame-$i.png" >> "$list"
  done
  magick "$tmp/grub/frame-0000.png" -depth 8 "PNG32:$tmp/grub/donut.png"
  install -D -m 644 "$tmp/grub/donut.png" "$R/boot/grub/themes/marc-os/donut.png"
  local G=$R/boot/grub/themes/marc-os p
  local base surface1 text lavender mantle subtext0
  read -r base surface1 text lavender mantle subtext0 < <(jq -r '[.base, .surface1, .text, .lavender, .mantle, .subtext0] | join(" ")' "$pal")
  magick -size 640x480 "xc:$base" "PNG24:$G/background.png"
  for p in c e w; do
    magick "$REPO/system/boot/grub/themes/marc-os/select_$p.png" -fill "$surface1" -colorize 100 "PNG32:$G/select_$p.png"
  done
  sed -i "s/#1E1E2E/${base^^}/I; s/#B4BEFE/${lavender^^}/Ig; s/#CDD6F4/${text^^}/Ig; s/#A6ADC8/${subtext0^^}/Ig" "$G/theme.txt"
  local P=$R/usr/share/plymouth/themes/marc-os
  magick -size 340x46 xc:none -fill "$mantle" -stroke "$lavender" -strokewidth 2 -draw "roundrectangle 1,1 338,44 22,22" "PNG32:$P/field.png"
  magick -size 10x10 xc:none -fill "$lavender" -draw "circle 5,5 5,1" "PNG32:$P/bullet.png"
  printf '%s\n' usr/share/plymouth/themes/marc-os/field.png usr/share/plymouth/themes/marc-os/bullet.png >> "$list"
  awk -v a="$base" -v b="$mantle" -v t="$text" -v l="$lavender" 'function c(h, i) { return sprintf("%.3f", strtonum("0x" substr(h, i, 2)) / 255) }
    /SetBackgroundTopColor/ { $0 = "Window.SetBackgroundTopColor(" c(a, 2) ", " c(a, 4) ", " c(a, 6) ");" }
    /SetBackgroundBottomColor/ { $0 = "Window.SetBackgroundBottomColor(" c(b, 2) ", " c(b, 4) ", " c(b, 6) ");" }
    /^fg_r = / { $0 = "fg_r = " c(t, 2) "; fg_g = " c(t, 4) "; fg_b = " c(t, 6) ";" }
    /^accent_r = / { $0 = "accent_r = " c(l, 2) "; accent_g = " c(l, 4) "; accent_b = " c(l, 6) ";" }
    { print }' "$REPO/system/usr/share/plymouth/themes/marc-os/marc-os.script" > "$P/marc-os.script"
  mkdir -p "$R/usr/share/sddm/themes"
  magick -size 1920x1080 "xc:$base" "$tmp/sddm/frame-0000.png" -gravity north -geometry +0+40 -composite "$R/usr/share/sddm/themes/torus-background.png"
  rm -rf "$tmp"
  printf '%s\n' boot/grub/themes/marc-os/donut.png usr/share/sddm/themes/torus-background.png >> "$list"
  sort -u -o "$list" "$list"

  local T=usr/share/sddm/themes/torus frag
  install -D -m 644 "$REPO/home/.config/quickshell/torus/background/donut.mjs" "$R/$T/donut.mjs"
  for frag in torus donut; do
    "$qsb" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$R/$T/$frag.frag.qsb" "$REPO/home/.config/quickshell/torus/background/$frag.frag"
  done
  jq -r --arg a "$accent" '"[General]", (. as $p | {base, mantle, crust, text, subtext: .subtext0, overlay: .overlay0, surface0, surface1, accent: $p[$a], red, mauve, lavender} | to_entries[] | "\(.key)=\"\(.value)\"")' "$pal" > "$R/$T/theme.conf.user"
  install -D -m 755 "$REPO/sddm/xsetup" "$R/usr/local/lib/torus/sddm-xsetup"
  mkdir -p "$R/etc/torus"
  : > "$R/etc/torus/sddm-monitors"
  local mon=${TORUS_MONITORS:-$uhome/.config/hypr/monitors.lua} out pos tr name
  if [[ -r $mon ]]; then
    while read -r out pos tr; do
      name=$("$REPO/sddm/xsetup" --edid-name "$(ls "${TORUS_SYSFS:-/sys}"/class/drm/card*-"$out"/edid 2> /dev/null | head -n 1)" 2> /dev/null || true)
      [[ -n $name ]] && echo "$name $tr ${pos%x*} ${pos#*x}" >> "$R/etc/torus/sddm-monitors"
    done < <(awk -F'"' '
      /output *=/ { out = $2 }
      /position *=/ { pos = $2 }
      /transform *=/ { split($0, a, "="); tr = a[2] + 0 }
      /^}\)/ { if (out != "") print out, (pos == "" ? "0x0" : pos), tr + 0; out = ""; pos = ""; tr = 0 }
    ' "$mon")
  fi
  mkdir -p "$R/etc/sddm.conf.d"
  printf '[Theme]\nCurrent=torus\n\n[X11]\nDisplayCommand=/usr/local/lib/torus/sddm-xsetup\n' > "$R/etc/sddm.conf.d/zz-torus.conf"
  printf '%s\n' "$T/donut.mjs" "$T/torus.frag.qsb" "$T/donut.frag.qsb" "$T/theme.conf.user" usr/local/lib/torus/sddm-xsetup etc/torus/sddm-monitors >> "$list"
  sort -u -o "$list" "$list"

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
  echo "torus: system theming done (flavour $flavour, accent $accent), original files in $attic"
}

system_undo() {
  local R=${root:-/}
  R=${R%/}
  local O=$R/var/lib/torus/original list=$R/var/lib/torus/installed.txt f prev
  [[ -d $O ]] || { echo "torus: nothing to undo, $O does not exist" >&2; exit 10; }
  if [[ -f $list ]]; then
    while IFS= read -r f; do
      [[ -n $f ]] && rm -f "$R/$f"
    done < "$list"
  fi
  rm -rf "$R/usr/share/plymouth/themes/marc-os" "$R/boot/grub/themes/marc-os" "$R/usr/share/sddm/themes/torus" "$R/usr/local/lib/torus" "$R/etc/torus"
  while IFS= read -r -d '' f; do
    [[ $f == absent.txt || $f == plymouth-theme ]] && continue
    install -D -m 644 "$O/$f" "$R/$f"
  done < <(cd "$O" && find . -type f -printf '%P\0')
  while IFS= read -r f; do
    [[ -n $f ]] && rm -f "$R/$f"
  done < "$O/absent.txt"
  prev=$(cat "$O/plymouth-theme" 2> /dev/null || true)
  [[ -n $prev ]] && plymouth-set-default-theme "$prev"
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
  rm -rf "$O" "$list"
  echo "torus: system files are back to how they were before torus"
}

if ((system)); then
  if [[ -z $root ]] && [[ $EUID -ne 0 || -z ${SUDO_USER:-} ]]; then
    echo "run with sudo: sudo $0 --system$( ((undo)) && echo " --undo")" >&2
    exit 2
  fi
  if ((undo)); then
    system_undo
    exit 0
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
  hyprctl monitors > /dev/null 2>&1 && "$REPO/home/.local/bin/torus-reload" || true
  "$REPO/home/.local/bin/torus-doctor" --reload-shell > /dev/null 2>&1 || true
fi
exit 0
