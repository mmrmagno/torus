#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkfixture "$F"
H=$F/home R=$F/root

mkdir -p "$H/.config/kitty" "$H/.config/Proton Pass" "$H/.config/chromium/Default/Cache" \
  "$H/.local/bin" "$H/.config/systemd/user" "$H/.local/share/Steam" "$H/Downloads" "$R/etc/default"
echo "font_size 9" > "$H/.config/kitty/kitty.conf"
echo "secret" > "$H/.config/Proton Pass/x"
echo "blob" > "$H/.config/chromium/Default/Cache/blob"
echo "game" > "$H/.local/share/Steam/game"
echo "zsh" > "$H/.zshrc"
echo "log" > "$H/.config/kitty/kitty.log"
echo "log" > "$H/.config/kitty/kitty.log.1"
echo "id" > "$H/.config/kitty/.uuid"
ln -s /opt/claude "$H/.local/bin/claude"
ln -s /dev/null "$H/.config/systemd/user/dunst.service"
echo 'GRUB_TIMEOUT=5' > "$R/etc/default/grub"

out=$("$REPO/backup/backup.sh" --home "$H" --root "$R" --out "$F/out" --skip-lists --keep-stage)
dir=$(tail -1 <<<"$out")
S=$dir/stage

assert_file "$S/home/.config/kitty/kitty.conf"
assert_file "$S/home/.config/Proton Pass/x"
assert_file "$S/home/.zshrc"
assert_absent "$S/home/.config/kitty/kitty.log"
assert_absent "$S/home/.config/kitty/kitty.log.1"
assert_absent "$S/home/.config/kitty/.uuid"
assert_absent "$S/home/.config/chromium/Default/Cache"
assert_absent "$S/home/.local/share/Steam"
assert_link "$S/home/.local/bin/claude" /opt/claude
assert_link "$S/home/.config/systemd/user/dunst.service" /dev/null
assert_file "$S/system/etc/default/grub"
assert_file "$S/meta/scope.txt"
assert_contains "$S/meta/excluded.txt" "Downloads"

rm -rf "$F/out"/*
out=$(TORUS_STAMP=20260101-000000 "$REPO/backup/backup.sh" --home "$H" --root "$R" --out "$F/out" --skip-lists)
dir=$(tail -1 <<<"$out")
assert_eq "$F/out/20260101-000000" "$dir" "backup dir"
assert_absent "$dir/stage"
assert_file "$dir/torus-backup-20260101-000000.tar.zst"
(cd "$dir" && sha256sum -c --quiet torus-backup-20260101-000000.tar.zst.sha256) || fail "tarball sha"
assert_file "$dir/MANIFEST.sha256"
assert_eq 8 "$(wc -l < "$dir/MANIFEST.sha256")" "manifest lines"
assert_contains "$dir/MANIFEST.sha256" "home/.config/Proton Pass/x"
assert_contains "$dir/LINKS.txt" "home/.local/bin/claude	/opt/claude"
assert_contains "$dir/LINKS.txt" "home/.config/systemd/user/dunst.service	/dev/null"
tar -tf "$dir/torus-backup-20260101-000000.tar.zst" | grep -qx 'MANIFEST.sha256' || fail "manifest not in tarball"
tar -tf "$dir/torus-backup-20260101-000000.tar.zst" | grep -qx 'home/.config/kitty/kitty.conf' || fail "kitty.conf not in tarball"

rc=0
TORUS_STAMP=20260101-000000 "$REPO/backup/backup.sh" --home "$H" --root "$R" --out "$F/out" --skip-lists >/dev/null 2>&1 || rc=$?
assert_eq 3 "$rc" "same stamp exit code"

rc=0
"$REPO/backup/backup.sh" --out "$F/guard" >/dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "non-root exit code"
assert_absent "$F/guard"
