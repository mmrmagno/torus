#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/stubs.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkfixture "$F"
H=$F/home R=$F/root
export TORUS_DIR=$F/torus STUB_LOG=$F/calls
mkstubs "$F/bin"
export PATH=$F/bin:$PATH

mkdir -p "$H/.config/kitty" "$R/etc" "$R/boot/grub"
echo "font_size 9" > "$H/.config/kitty/kitty.conf"
echo "host-a" > "$R/etc/machine-id"
echo "UUID=host-root / ext4" > "$R/etc/fstab"
echo "menuentry host" > "$R/boot/grub/grub.cfg"
printf '[core]\nInclude = x\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' > "$R/etc/pacman.conf"

cat > "$F/scope.txt" <<'S'
home + .config
system + /etc/pacman.conf
system + /etc/fstab
system + /etc/machine-id
system + /boot/grub/grub.cfg
system + /etc/mkinitcpio.conf
S
export TORUS_SCOPE=$F/scope.txt
dir=$(TORUS_STAMP=20260101-000000 "$REPO/backup/backup.sh" --home "$H" --root "$R" --out "$F/out" | tail -1)
assert_eq "host-a" "$(cat "$dir/meta/machine-id")" "machine-id recorded"
assert_contains "$dir/meta/pkg-native.txt" "ghost-pkg"
assert_contains "$dir/meta/units-system.txt" "sddm.service"
assert_contains "$dir/meta/masked-user.txt" "dunst.service"

echo "font_size 20" > "$H/.config/kitty/kitty.conf"
echo "vm-b" > "$R/etc/machine-id"
echo "UUID=vm-root / ext4" > "$R/etc/fstab"
: > "$STUB_LOG"
"$REPO/backup/restore.sh" "$dir" --home "$H" --root "$R" --dry-run > "$F/dry"
assert_eq "font_size 20" "$(cat "$H/.config/kitty/kitty.conf")" "dry run changes nothing"
assert_eq 0 "$(grep -vc "^pacman -Q" "$STUB_LOG")" "dry run only queries"
order=$(grep -nE '^\+ (pacman-key --config \S+ --recv-key|pacman -Syu|yay -S|flatpak install|systemctl enable|systemctl --user mask|grub-mkconfig|sbctl sign-all)' "$F/dry" | cut -d' ' -f2-3 | tr '\n' '|')
assert_eq "pacman-key --config|pacman -Syu|yay -S|flatpak install|systemctl enable|systemctl --user|grub-mkconfig -o|sbctl sign-all|" "$order" "command order"
grep '^+ yay -S' "$F/dry" | grep -q 'yay-debug' && fail "yay-debug should be skipped"
assert_contains "$F/dry" "+ systemctl --user mask dunst.service"

rc=0
export GRANT=$R/etc/sudoers.d/zz-torus-restore
printf '#!/usr/bin/env bash\necho "yay $*" >> "$STUB_LOG"\n[ -e "$GRANT" ] && echo "yay saw grant: $(cat "$GRANT")" >> "$STUB_LOG"\nexit 0\n' > "$F/bin/yay"
"$REPO/backup/restore.sh" "$dir" --home "$H" --root "$R" > "$F/real" 2>&1 || rc=$?
assert_eq 7 "$rc" "missing packages exit code"
grep -q "^yay saw grant: $(id -un) ALL=(ALL) NOPASSWD: ALL" "$STUB_LOG" || fail "yay runs with a temporary sudo grant: $(grep yay "$STUB_LOG" | head -3)"
grep '^yay -S' "$STUB_LOG" | grep -qv -- '--nosudoloop' && fail "yay must not loop on sudo"
assert_absent "$GRANT"
assert_contains "$dir/missing-packages.txt" "ghost-pkg"
assert_eq "font_size 9" "$(cat "$H/.config/kitty/kitty.conf")" "files restored"
assert_contains "$STUB_LOG" "pacman -S --needed --noconfirm base"
grep -qx 'pacman -Syu --noconfirm' "$STUB_LOG" || fail "full upgrade without targets must run before the fallback"
grep -q '^pacman -S --needed --noconfirm ghost-pkg' "$STUB_LOG" && fail "packages unknown to the repos must not be attempted one by one"
assert_contains "$STUB_LOG" "pacman-key config-clean"
assert_contains "$STUB_LOG" "pacman-key --populate chaotic"
grep -q 'config-has-chaotic\|config-missing' "$STUB_LOG" && fail "chaotic bootstrap must use a pacman.conf without [chaotic-aur]"
assert_contains "$STUB_LOG" "grub-mkconfig -o"
assert_contains "$STUB_LOG" "sbctl verify"
assert_contains "$F/real" "restore verified"
assert_contains "$F/real" "skipped, other machine: system/etc/fstab"
assert_eq "UUID=vm-root / ext4" "$(cat "$R/etc/fstab")" "fstab of the other machine kept"
assert_eq "vm-b" "$(cat "$R/etc/machine-id")" "machine-id of the other machine kept"

echo "host-a" > "$R/etc/machine-id"
echo "menuentry torus" > "$R/boot/grub/grub.cfg"
: > "$STUB_LOG"
"$REPO/backup/restore.sh" "$dir" --home "$H" --root "$R" > "$F/same" 2>&1 || true
assert_eq "UUID=host-root / ext4" "$(cat "$R/etc/fstab")" "same machine restores fstab"
assert_eq "menuentry host" "$(cat "$R/boot/grub/grub.cfg")" "same machine restores grub.cfg exactly"
grep -q '^grub-mkconfig' "$STUB_LOG" && fail "grub-mkconfig must not run on the same machine"
assert_contains "$F/same" "restore verified"
echo "vm-b" > "$R/etc/machine-id"
grep -q '^mkinitcpio' "$STUB_LOG" && fail "mkinitcpio should not run when mkinitcpio.conf is unchanged"

rc=0
STUB_UNSIGNED=1 "$REPO/backup/restore.sh" "$dir" --home "$H" --root "$R" > "$F/real" 2>&1 || rc=$?
assert_eq 6 "$rc" "unsigned boot file exit code"

echo 'HOOKS=(base udev)' > "$R/etc/mkinitcpio.conf"
dir2=$(TORUS_STAMP=20260101-000001 "$REPO/backup/backup.sh" --home "$H" --root "$R" --out "$F/out" | tail -1)
echo 'HOOKS=(base udev plymouth)' > "$R/etc/mkinitcpio.conf"
: > "$STUB_LOG"
"$REPO/backup/restore.sh" "$dir2" --home "$H" --root "$R" > /dev/null 2>&1 || true
assert_contains "$STUB_LOG" "mkinitcpio -P"

dir3=$(STUB_NO_MASKED=1 TORUS_STAMP=20260101-000002 "$REPO/backup/backup.sh" --home "$H" --root "$R" --out "$F/out" | tail -1)
assert_eq "$F/out/20260101-000002" "$dir3" "backup survives systemctl exit 1 on an empty list"
assert_eq 0 "$(wc -c < "$dir3/meta/masked-user.txt")" "empty masked list"

rc=0
STUB_ENABLE_FAIL=1 "$REPO/backup/restore.sh" "$dir" --home "$H" --root "$R" > "$F/units" 2>&1 || rc=$?
assert_eq 8 "$rc" "failed unit enable exit code"
assert_contains "$F/units" "sddm.service"

rc=0
"$REPO/backup/restore.sh" "$dir" > "$F/nosudo" 2>&1 || rc=$?
assert_eq 2 "$rc" "restore without sudo refused"
