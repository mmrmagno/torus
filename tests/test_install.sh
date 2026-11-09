#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
H=$F/home P=$F/repo
mkdir -p "$H/.config/kitty" "$H/.config/hypr" "$P/home/.config/kitty" "$P/home/.config/hypr"
cp "$REPO/install.sh" "$P/install.sh"
echo "mine" > "$H/.config/kitty/kitty.conf"
ln -s /x "$H/.zshrc"
echo "monitors" > "$H/.config/hypr/monitors.lua"
echo "torus kitty" > "$P/home/.config/kitty/kitty.conf"
echo "torus zsh" > "$P/home/.zshrc"
echo "torus hypr" > "$P/home/.config/hypr/hyprland.lua"
echo "repo monitors" > "$P/home/.config/hypr/monitors.lua"

"$P/install.sh" --home "$H" --no-packages --dry-run > "$F/dry"
assert_eq "mine" "$(cat "$H/.config/kitty/kitty.conf")" "dry run changes nothing"
assert_link "$H/.zshrc" /x

"$P/install.sh" --home "$H" --no-packages > "$F/first"
assert_link "$H/.config/kitty/kitty.conf" "$P/home/.config/kitty/kitty.conf"
assert_link "$H/.zshrc" "$P/home/.zshrc"
assert_link "$H/.config/hypr/hyprland.lua" "$P/home/.config/hypr/hyprland.lua"
assert_eq "monitors" "$(cat "$H/.config/hypr/monitors.lua")" "monitors.lua untouched"
attic=$(find "$H/.local/share/torus/attic" -mindepth 1 -maxdepth 1 -type d)
assert_eq "mine" "$(cat "$attic/.config/kitty/kitty.conf")" "old kitty.conf in attic"
assert_link "$attic/.zshrc" /x

"$P/install.sh" --home "$H" --no-packages > "$F/second"
assert_contains "$F/second" "torus: linked 0, kept 3, moved 0"

R=$F/root
mkdir -p "$R/etc/default" "$R/boot/grub" "$R/usr/share/sddm/themes/catppuccin-mocha-mauve"
printf 'GRUB_DEFAULT=0\nGRUB_TIMEOUT=5\nGRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"\nGRUB_THEME="/boot/grub/themes/hollow-grub/theme.txt"\n' > "$R/etc/default/grub"
printf 'MODULES=()\nHOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)\n' > "$R/etc/mkinitcpio.conf"
export STUB_LOG=$F/syscalls
mkdir -p "$F/sbin"
for c in grub-mkconfig mkinitcpio plymouth-set-default-theme; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$STUB_LOG"\n' "$c" > "$F/sbin/$c"; done
printf '#!/usr/bin/env bash\necho "sbctl $*" >> "$STUB_LOG"\n[[ $1 == verify ]] && { echo "✗ /boot/grub/x86_64-efi/core.efi is not signed"; [[ -n ${STUB_UNSIGNED:-} ]] && echo "✗ /boot/vmlinuz-linux is not signed"; echo "✓ /boot/EFI/BOOT/BOOTX64.EFI is signed"; }\nexit 0\n' > "$F/sbin/sbctl"
chmod +x "$F/sbin"/*
export TORUS_SYSFS=$F/sys TORUS_MONITORS=$F/monitors.lua
mkedid "$F/sys/class/drm/card1-DP-1/edid" VG27AQ1A
mkedid "$F/sys/class/drm/card1-DP-2/edid" Q27G2WG4
printf 'hl.monitor({\n    output = "DP-2",\n    mode = "2560x1440@120.0",\n    position = "2560x410",\n    scale = 1.0,\n    transform = 3\n})\nhl.monitor({\n    output = "DP-1",\n    mode = "2560x1440@144.01",\n    position = "0x1467",\n    scale = 1\n})\n' > "$F/monitors.lua"

PATH=$F/sbin:$PATH "$REPO/install.sh" --system --root "$R" --accent mauve --flavour mocha > "$F/sys1"
PATH=$F/sbin:$PATH "$REPO/install.sh" --system --root "$R" --accent mauve --flavour mocha > "$F/sys2"
assert_contains "$R/etc/default/grub" 'GRUB_THEME="/boot/grub/themes/marc-os/theme.txt"'
assert_eq 1 "$(grep -o 'splash' "$R/etc/default/grub" | wc -l)" "splash added once"
assert_contains "$R/etc/default/grub" 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash"'
assert_contains "$R/etc/mkinitcpio.conf" "HOOKS=(base udev plymouth autodetect"
assert_eq 1 "$(grep -o 'plymouth' "$R/etc/mkinitcpio.conf" | wc -l)" "plymouth hook added once"
assert_file "$R/boot/grub/themes/marc-os/theme.txt"
assert_file "$R/boot/grub/themes/marc-os/donut.png"
assert_file "$R/usr/share/plymouth/themes/marc-os/marc-os.script"
assert_file "$R/usr/share/plymouth/themes/marc-os/frame-89.png"
assert_file "$R/usr/share/sddm/themes/torus-background.png"
assert_contains "$R/etc/sddm.conf.d/zz-torus.conf" "Current=torus"
assert_contains "$R/etc/sddm.conf.d/zz-torus.conf" "DisplayCommand=/usr/local/lib/torus/sddm-xsetup"
[[ -x $R/usr/local/lib/torus/sddm-xsetup ]] || fail "sddm-xsetup not executable"
T=$R/usr/share/sddm/themes/torus
for f in Main.qml metadata.desktop donut.mjs torus.frag.qsb donut.frag.qsb; do assert_file "$T/$f"; done
assert_contains "$T/theme.conf.user" 'accent="#cba6f7"'
assert_contains "$R/etc/torus/sddm-monitors" "Q27G2WG4 3 2560 410"
assert_contains "$R/etc/torus/sddm-monitors" "VG27AQ1A 0 0 1467"
[[ -e $R/usr/share/sddm/themes/catppuccin-mocha-mauve/theme.conf.user ]] && fail "catppuccin theme must stay untouched"
ls "$R/var/lib/torus/attic/"*/etc/default/grub > /dev/null || fail "original grub default kept in attic"
order=$(grep -oE '^(plymouth-set-default-theme marc-os|grub-mkconfig|mkinitcpio|sbctl sign-all|sbctl verify)' "$STUB_LOG" | head -5 | tr '\n' '|')
assert_eq "plymouth-set-default-theme marc-os|grub-mkconfig|mkinitcpio|sbctl sign-all|sbctl verify|" "$order" "system command order"
grep -q 'grub-install' "$STUB_LOG" && fail "grub-install must never run"
rc=0
STUB_UNSIGNED=1 PATH=$F/sbin:$PATH "$REPO/install.sh" --system --root "$R" --accent mauve --flavour mocha > /dev/null 2>&1 || rc=$?
assert_eq 6 "$rc" "unsigned boot file blocks install"
rc=0
"$REPO/install.sh" --system > /dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "system mode needs sudo"

cp "$R/etc/default/grub" "$F/grub.before"
cp "$R/etc/mkinitcpio.conf" "$F/mk.before"
mkdir -p "$F/sbin-partial"
for c in grub-mkconfig mkinitcpio sbctl; do cp "$F/sbin/$c" "$F/sbin-partial/$c"; done
sed -i 's|^GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/hollow-grub/theme.txt"|' "$R/etc/default/grub"
cp "$R/etc/default/grub" "$F/grub.before"
rc=0
mkdir -p "$F/usrbin"
for b in /usr/bin/*; do [[ ${b##*/} == plymouth-set-default-theme ]] || ln -s "$b" "$F/usrbin/${b##*/}"; done
PATH=$F/sbin-partial:$F/usrbin "$REPO/install.sh" --system --root "$R" --accent mauve --flavour mocha > "$F/partial" 2>&1 || rc=$?
assert_eq 3 "$rc" "missing tool stops before any edit"
cmp -s "$F/grub.before" "$R/etc/default/grub" || fail "grub default touched although a tool was missing"
assert_contains "$F/partial" "plymouth-set-default-theme"

PATH=$F/sbin:$PATH "$REPO/install.sh" --system --root "$R" --accent blue --flavour mocha > /dev/null 2>&1
assert_contains "$R/usr/share/sddm/themes/torus/theme.conf.user" 'accent="#89b4fa"'
assert_contains "$R/usr/share/sddm/themes/torus/theme.conf.user" 'base="#1e1e2e"'
G=$R/boot/grub/themes/marc-os
cmp -s "$REPO/system/boot/grub/themes/marc-os/theme.txt" "$G/theme.txt" || fail "mocha grub theme.txt changed"
cmp -s "$REPO/system/usr/share/plymouth/themes/marc-os/marc-os.script" "$R/usr/share/plymouth/themes/marc-os/marc-os.script" || fail "mocha plymouth script changed"
assert_eq "1E1E2E" "$(magick "$G/background.png" -alpha off -depth 8 -format '%[hex:p{5,5}]' info:)" "mocha grub background"
TORUS_PLY_FRAMES=2 PATH=$F/sbin:$PATH "$REPO/install.sh" --system --root "$R" --accent blue --flavour latte > "$F/latte"
assert_contains "$F/latte" "flavour latte"
assert_contains "$R/usr/share/sddm/themes/torus/theme.conf.user" 'base="#eff1f5"'
assert_contains "$R/usr/share/sddm/themes/torus/theme.conf.user" 'accent="#1e66f5"'
assert_contains "$R/usr/share/sddm/themes/torus/theme.conf.user" 'text="#4c4f69"'
assert_contains "$G/theme.txt" 'desktop-color: "#EFF1F5"'
assert_contains "$G/theme.txt" 'item_color = "#4C4F69"'
grep -qi 'CDD6F4\|1E1E2E\|B4BEFE' "$G/theme.txt" && fail "latte grub theme keeps mocha colours"
assert_contains "$R/usr/share/plymouth/themes/marc-os/marc-os.script" "SetBackgroundTopColor(0.937, 0.945, 0.961)"
assert_eq "EFF1F5" "$(magick "$G/background.png" -alpha off -depth 8 -format '%[hex:p{5,5}]' info:)" "latte grub background"
assert_eq "CCD0DA" "$(magick "$G/select_c.png" -alpha off -depth 8 -format '%[hex:p{2,10}]' info:)" "latte grub selection"
assert_eq "EFF1F5" "$(magick "$R/usr/share/sddm/themes/torus-background.png" -alpha off -depth 8 -format '%[hex:p{5,1000}]' info:)" "latte sddm background"
rc=0
PATH=$F/sbin:$PATH "$REPO/install.sh" --system --root "$R" --flavour espresso > /dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "unknown flavour"
R2=$F/root2
mkdir -p "$R2/etc/default" "$R2/boot/grub" "$R2/usr/share/sddm/themes/catppuccin-mocha-mauve"
printf 'GRUB_DEFAULT=0\nGRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"\nGRUB_THEME="/boot/grub/themes/hollow-grub/theme.txt"\n' > "$R2/etc/default/grub"
printf 'MODULES=()\nHOOKS=(base udev autodetect modconf block filesystems fsck)\n' > "$R2/etc/mkinitcpio.conf"
cp "$R2/etc/default/grub" "$F/g2.before"; cp "$R2/etc/mkinitcpio.conf" "$F/m2.before"
printf '#!/usr/bin/env bash\necho "plymouth-set-default-theme $*" >> "$STUB_LOG"\n(($#)) || echo bgrt\n' > "$F/sbin/plymouth-set-default-theme"
rc=0; PATH=$F/sbin:$PATH "$REPO/install.sh" --system --undo --root "$R2" > /dev/null 2>&1 || rc=$?
assert_eq 10 "$rc" "undo without originals"
PATH=$F/sbin:$PATH "$REPO/install.sh" --system --root "$R2" --accent mauve --flavour mocha > /dev/null
O=$R2/var/lib/torus/original
assert_contains "$O/etc/default/grub" "hollow-grub"
assert_contains "$O/absent.txt" "etc/sddm.conf.d/zz-torus.conf"
assert_eq bgrt "$(cat "$O/plymouth-theme")" "previous plymouth theme saved"
PATH=$F/sbin:$PATH "$REPO/install.sh" --system --root "$R2" --accent mauve --flavour mocha > /dev/null
assert_contains "$O/etc/default/grub" "hollow-grub"
assert_eq "$(sort -u "$R2/var/lib/torus/installed.txt" | wc -l)" "$(wc -l < "$R2/var/lib/torus/installed.txt")" "installed list has no duplicates"
mapfile -t inst < "$R2/var/lib/torus/installed.txt"
((${#inst[@]} > 90)) || fail "installed list too short: ${#inst[@]}"
: > "$STUB_LOG"
PATH=$F/sbin:$PATH "$REPO/install.sh" --system --undo --root "$R2" > /dev/null
cmp -s "$F/g2.before" "$R2/etc/default/grub" || fail "grub default not byte-identical after undo"
cmp -s "$F/m2.before" "$R2/etc/mkinitcpio.conf" || fail "mkinitcpio.conf not byte-identical after undo"
assert_absent "$R2/etc/sddm.conf.d/zz-torus.conf"
for f in "${inst[@]}"; do assert_absent "$R2/$f"; done
assert_absent "$R2/usr/share/plymouth/themes/marc-os"
assert_absent "$R2/boot/grub/themes/marc-os"
assert_absent "$R2/usr/share/sddm/themes/torus"
assert_absent "$R2/usr/local/lib/torus"
assert_absent "$R2/etc/torus"
assert_absent "$R2/var/lib/torus/original"
assert_absent "$R2/var/lib/torus/installed.txt"
assert_contains "$STUB_LOG" "plymouth-set-default-theme bgrt"
order=$(grep -oE '^(grub-mkconfig|mkinitcpio -P|sbctl sign-all)' "$STUB_LOG" | tr '\n' '|')
assert_eq "grub-mkconfig|mkinitcpio -P|sbctl sign-all|" "$order" "undo regenerates and signs"
grep -q 'grub-install' "$STUB_LOG" && fail "grub-install must never run"
true
