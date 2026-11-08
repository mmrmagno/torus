#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkfixture "$F"
H=$F/home R=$F/root T=$F/torus
export TORUS_DIR=$T

mkdir -p "$H/.config/kitty" "$H/.config/Proton Pass" "$H/.local/bin" "$R/etc/default" "$T/home/.config/hypr"
chmod 710 "$H"
chmod 750 "$R"
echo "font_size 9" > "$H/.config/kitty/kitty.conf"
echo "secret" > "$H/.config/Proton Pass/x"
ln -s /opt/claude "$H/.local/bin/claude"
echo 'GRUB_TIMEOUT=5' > "$R/etc/default/grub"

dir=$(TORUS_STAMP=20260101-000000 "$REPO/backup/backup.sh" --home "$H" --root "$R" --out "$F/out" --skip-lists | tail -1)

echo "font_size 20" > "$H/.config/kitty/kitty.conf"
rm "$H/.config/Proton Pass/x"
rm "$H/.local/bin/claude" && echo "not a link" > "$H/.local/bin/claude"
echo 'GRUB_TIMEOUT=0' > "$R/etc/default/grub"
ln -s "$T/home/.config/hypr" "$H/.config/hypr"

"$REPO/backup/restore.sh" "$dir" --home "$H" --root "$R" --files-only > "$F/log"
assert_contains "$F/log" "restore verified: 3 files"
assert_eq "font_size 9" "$(cat "$H/.config/kitty/kitty.conf")" "kitty.conf restored"
kept=$(find "$H/.local/share/torus/attic" -path '*-replaced/.config/kitty/kitty.conf' 2> /dev/null | head -n 1 || true)
assert_eq "font_size 20" "$(cat "$kept" 2> /dev/null)" "replaced file kept in the attic"
assert_contains "$F/log" "replaced files kept in"
assert_file "$H/.config/Proton Pass/x"
assert_link "$H/.local/bin/claude" /opt/claude
assert_eq 'GRUB_TIMEOUT=5' "$(cat "$R/etc/default/grub")" "grub restored"
assert_absent "$H/.config/hypr"
assert_absent "$dir/.unpack"
assert_eq 710 "$(stat -c %a "$H")" "home mode kept"
assert_eq 750 "$(stat -c %a "$R")" "root mode kept"

echo "font_size 20" > "$H/.config/kitty/kitty.conf"
rc=0
"$REPO/backup/restore.sh" "$dir" --home "$H" --root "$R" --verify-only > "$F/log" 2>&1 || rc=$?
assert_eq 5 "$rc" "verify-only detects drift"
assert_contains "$F/log" "home/.config/kitty/kitty.conf"
assert_eq "font_size 20" "$(cat "$H/.config/kitty/kitty.conf")" "verify-only changes nothing"

mkdir -p "$F/elsewhere/home/.config/quickshell"
ln -s "$F/elsewhere/home/.config/quickshell" "$H/.config/quickshell"
env -u TORUS_DIR "$REPO/backup/restore.sh" "$dir" --home "$H" --root "$R" --files-only --torus "$F/elsewhere" > "$F/log"
assert_absent "$H/.config/quickshell"
echo "font_size 20" > "$H/.config/kitty/kitty.conf"

tb=$dir/torus-backup-20260101-000000.tar.zst
printf '\x00' | dd of="$tb" bs=1 seek=100 conv=notrunc status=none
rc=0
"$REPO/backup/restore.sh" "$dir" --home "$H" --root "$R" --files-only > "$F/log" 2>&1 || rc=$?
assert_eq 4 "$rc" "tampered tarball refused"
assert_eq "font_size 20" "$(cat "$H/.config/kitty/kitty.conf")" "fixture untouched after refusal"
