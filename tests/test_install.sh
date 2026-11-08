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

PATH=$F/sbin:$PATH "$REPO/install.sh" --system --root "$R" --accent mauve > "$F/sys1"
PATH=$F/sbin:$PATH "$REPO/install.sh" --system --root "$R" --accent mauve > "$F/sys2"
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
assert_contains "$R/etc/sddm.conf.d/zz-torus.conf" "Current=catppuccin-mocha-mauve"
assert_contains "$R/usr/share/sddm/themes/catppuccin-mocha-mauve/theme.conf.user" "torus-background.png"
ls "$R/var/lib/torus/attic/"*/etc/default/grub > /dev/null || fail "original grub default kept in attic"
order=$(grep -oE '^(plymouth-set-default-theme|grub-mkconfig|mkinitcpio|sbctl sign-all|sbctl verify)' "$STUB_LOG" | head -5 | tr '\n' '|')
assert_eq "plymouth-set-default-theme|grub-mkconfig|mkinitcpio|sbctl sign-all|sbctl verify|" "$order" "system command order"
grep -q 'grub-install' "$STUB_LOG" && fail "grub-install must never run"
rc=0
STUB_UNSIGNED=1 PATH=$F/sbin:$PATH "$REPO/install.sh" --system --root "$R" --accent mauve > /dev/null 2>&1 || rc=$?
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
PATH=$F/sbin-partial:/usr/bin:/bin "$REPO/install.sh" --system --root "$R" --accent mauve > "$F/partial" 2>&1 || rc=$?
if command -v plymouth-set-default-theme > /dev/null; then rc=3; fi
assert_eq 3 "$rc" "missing tool stops before any edit"
cmp -s "$F/grub.before" "$R/etc/default/grub" || fail "grub default touched although a tool was missing"
assert_contains "$F/partial" "plymouth-set-default-theme"

rm -rf "$R/usr/share/sddm/themes/catppuccin-mocha-mauve"
rm -f "$R/etc/sddm.conf.d/zz-torus.conf"
PATH=$F/sbin:$PATH "$REPO/install.sh" --system --root "$R" --accent mauve > /dev/null 2>&1
[[ -e $R/etc/sddm.conf.d/zz-torus.conf ]] && fail "sddm theme selected although it is not installed"
true
