#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkfixture "$F"
H=$F/home R=$F/root
mkdir -p "$H/.config/kitty" "$R/etc"
echo "font_size 9" > "$H/.config/kitty/kitty.conf"
dir=$(TORUS_STAMP=20260101-000000 "$REPO/backup/backup.sh" --home "$H" --root "$R" --out "$F/out" --skip-lists | tail -1)

age-keygen -o "$F/key" 2>/dev/null
grep -o 'age1[0-9a-z]*' "$F/key" > "$F/recipient"

"$REPO/backup/offsite.sh" push "$dir" --dest "$F/remote" --recipient "$F/recipient" > "$F/log"
assert_file "$F/remote/torus-backup-20260101-000000.tar.zst.age"
assert_file "$F/remote/torus-backup-20260101-000000.tar.zst.sha256"
tar -tf "$F/remote/torus-backup-20260101-000000.tar.zst.age" >/dev/null 2>&1 && fail "remote copy is not encrypted"
assert_absent "$dir/.offsite"

"$REPO/backup/offsite.sh" fetch 20260101-000000 "$F/back" --src "$F/remote" --identity <(cat "$F/key") > "$F/log"
assert_eq 600 "$(stat -c %a "$F/back/torus-backup-20260101-000000.tar.zst")" "decrypted tarball private"
assert_eq "$(cut -d' ' -f1 "$dir/torus-backup-20260101-000000.tar.zst.sha256")" \
  "$(sha256sum "$F/back/torus-backup-20260101-000000.tar.zst" | cut -d' ' -f1)" "fetched tarball sha"

rc=0
"$REPO/backup/offsite.sh" push "$dir" --dest "$F/remote2" --recipient "$F/nope" > /dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "missing recipient exit code"
assert_absent "$F/remote2"
