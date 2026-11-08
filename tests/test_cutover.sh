#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export STUB_LOG=$F/calls
mkdir -p "$F/bin"
cat > "$F/bin/pacman" <<'S'
#!/usr/bin/env bash
echo "pacman $*" >> "$STUB_LOG"
case $1 in
  -Qq) shift; for p in "$@"; do [[ " ${STUB_INSTALLED:-} " == *" $p "* ]] && echo "$p"; done; exit 0 ;;
  -R*n*p*|-R*p*n*) echo "error: invalid option: '--nosave' and '--print' may not be used together" >&2; exit 1 ;;
  -R*p) exit "${STUB_RP_RC:-0}" ;;
  -Sw) exit "${STUB_SW_RC:-0}" ;;
esac
exit 0
S
printf '#!/usr/bin/env bash\necho "sudo $*" >> "$STUB_LOG"\nexec "$@"\n' > "$F/bin/sudo"
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$STUB_LOG"\nexit 0\n' > "$F/bin/systemctl"
printf '#!/usr/bin/env bash\necho "sbctl $*" >> "$STUB_LOG"\nprintf "%%b" "${STUB_SBCTL_OUT:-}"\n' > "$F/bin/sbctl"
chmod +x "$F/bin"/*
export PATH=$F/bin:$PATH

HYDE_PATHS=(HyDE .config/waybar .config/swaync .config/dunst .config/wlogout .config/hyde .local/share/hyde
  .local/share/hypr .local/share/waybar .local/share/wallbash .local/state/hyde .local/lib/hyde .cache/hyde
  .config/systemd/user/hyde-config.service .config/systemd/user/hyde-ipc.service
  .config/uwsm/env-hyprland .config/uwsm/env-hyprland.d/00-hyde.sh .config/uwsm/env.d/00-hyde.sh)

mkbackup() {
  local root=$1 stamp=$2 marker=$3 d
  d=$root/$stamp
  mkdir -p "$d"
  echo "payload $stamp" > "$d/torus-backup-$stamp.tar.zst"
  (cd "$d" && sha256sum "torus-backup-$stamp.tar.zst" > "torus-backup-$stamp.tar.zst.sha256")
  if ((marker)); then
    printf 'tarball_sha256=%s\ntested=x\n' "$(cut -d' ' -f1 "$d/torus-backup-$stamp.tar.zst.sha256")" > "$d/restore-tested"
  fi
  echo "$d"
}

setup() {
  rm -rf "$F/home" "$F/backups" "$F/state"
  : > "$STUB_LOG"
  local p
  for p in "${HYDE_PATHS[@]}"; do
    if [[ $p == *.service || $p == *.sh || $p == */env-hyprland ]]; then
      mkdir -p "$(dirname "$F/home/$p")"; echo unit > "$F/home/$p"
    else
      mkdir -p "$F/home/$p"; echo x > "$F/home/$p/file"
    fi
  done
  mkdir -p "$F/home/.local/bin"; echo mine > "$F/home/.local/bin/vpnup"
  echo mine > "$F/home/.config/uwsm/env.d/50-mine.sh"
  mkdir -p "$F/backups"
  export XDG_STATE_HOME=$F/state
}

run() { "$REPO/uninstall-current.sh" --home "$F/home" --backups "$F/backups" "$@"; }
now=$(date +%Y%m%d-%H%M%S)

setup
mkbackup "$F/backups" "$now" 0 > /dev/null
rc=0; run > /dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "gate refuses without restore-tested"
[[ -d $F/home/HyDE ]] || fail "untouched after refusal"

setup
mkbackup "$F/backups" "$(date -d '2 days ago' +%Y%m%d-%H%M%S)" 1 > /dev/null
rc=0; run > /dev/null 2>&1 || rc=$?
assert_eq 3 "$rc" "gate refuses a 2-day-old backup"

setup
d=$(mkbackup "$F/backups" "$now" 1)
echo corrupt >> "$d/torus-backup-$now.tar.zst"
rc=0; run > /dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "gate refuses a corrupted tarball"

setup
mkbackup "$F/backups" "$(date -d '3 days ago' +%Y%m%d-%H%M%S)" 1 > /dev/null
mkbackup "$F/backups" "$now" 0 > /dev/null
export STUB_INSTALLED="waybar swaync" STUB_RP_RC=1
rc=0; run > /dev/null 2>&1 || rc=$?
assert_eq 4 "$rc" "package dry-run failure"
for p in "${HYDE_PATHS[@]}"; do [[ -e $F/home/$p ]] || fail "moved despite package failure: $p"; done
grep -q 'pacman -Rns --noconfirm' "$STUB_LOG" && fail "removed packages despite dry-run failure"
assert_absent "$XDG_STATE_HOME/torus/cutover"

setup
mkbackup "$F/backups" "$now" 1 > /dev/null
export STUB_RP_RC=0 STUB_SW_RC=1
rc=0; run > "$F/out" 2>&1 || rc=$?
assert_eq 4 "$rc" "torus package download failure"
grep -q '^sudo pacman -Sw --needed --noconfirm .*quickshell' "$STUB_LOG" || fail "downloads torus packages first: $(grep Sw "$STUB_LOG")"
assert_contains "$F/out" "pacman -Syu"
for p in "${HYDE_PATHS[@]}"; do [[ -e $F/home/$p ]] || fail "moved despite download failure: $p"; done
export STUB_SW_RC=0

setup
mkbackup "$F/backups" "$now" 1 > /dev/null
export STUB_SBCTL_OUT='\u2717 /boot/EFI/Linux/old.efi is not signed\n\u2717 /boot/grub/x86_64-efi/core.efi is not signed\n'
rc=0; run > "$F/out" 2>&1 || rc=$?
assert_eq 5 "$rc" "unsigned EFI file refused"
assert_contains "$F/out" "old.efi"
assert_contains "$F/out" "sbctl sign-all"
for p in "${HYDE_PATHS[@]}"; do [[ -e $F/home/$p ]] || fail "moved despite unsigned EFI file: $p"; done
export STUB_SBCTL_OUT='\u2717 /boot/grub/x86_64-efi/core.efi is not signed\n'

setup
d=$(mkbackup "$F/backups" "$now" 1)
export STUB_RP_RC=0
out=$(run 2>&1)
attic=$(ls -d "$F/home/.local/share/torus/attic/"*-hyde)
for p in "${HYDE_PATHS[@]}"; do
  assert_absent "$F/home/$p"
  [[ -e $attic/$p ]] || fail "not in attic: $p"
done
assert_eq mine "$(cat "$F/home/.local/bin/vpnup")" "user scripts stay"
assert_eq mine "$(cat "$F/home/.config/uwsm/env.d/50-mine.sh")" "own uwsm env stays"
dis=$(grep -n 'systemctl --user disable --now hyde-config.service' "$STUB_LOG" | cut -d: -f1)
[[ -n $dis ]] || fail "hyde-config not disabled"
grep -q '^sudo pacman -Rns --noconfirm waybar swaync$' "$STUB_LOG" || fail "removes only installed packages: $(grep Rns "$STUB_LOG")"
assert_eq "backup=$d" "$(tail -n 1 <<<"$out")" "last line names the backup"
assert_eq "backup=$d" "$(cat "$XDG_STATE_HOME/torus/cutover")" "backup recorded before anything moved"

mkbackup "$F/backups" "$(date -d '1 minute' +%Y%m%d-%H%M%S)" 1 > /dev/null
rc=0; out=$(run 2>&1) || rc=$?
assert_eq 9 "$rc" "second run after cutover"
assert_eq "backup=$d" "$(tail -n 1 <<<"$out")" "second run keeps the first backup"

FX=$F/repo
mkdir -p "$FX/backup"
for n in install.sh uninstall-current.sh backup/restore.sh; do
  v=$(basename "$n" .sh | tr 'a-z-' 'A-Z_')
  printf '#!/usr/bin/env bash\necho "%s $*" >> "$STUB_LOG"\n[[ %s == uninstall-current.sh && ${STUB_%s_RC:-0} =~ ^[09]$ ]] && echo "backup=$STUB_BACKUP"\nexit "${STUB_%s_RC:-0}"\n' "$n" "$n" "$v" "$v" > "$FX/$n"
  chmod +x "$FX/$n"
done
cp "$REPO/cutover.sh" "$REPO/rollback.sh" "$FX/"
export TORUS_REPO=$FX STUB_BACKUP=$F/backups/20990101-000000 XDG_STATE_HOME=$F/state2
S=$XDG_STATE_HOME/torus/cutover
cut() { : > "$STUB_LOG"; rm -rf "$XDG_STATE_HOME"; "$FX/cutover.sh" > "$F/out" 2>&1; }

rc=0; cut || rc=$?
assert_eq 0 "$rc" "cutover succeeds"
assert_eq "uninstall-current.sh|install.sh|sudo $FX/install.sh --system|" "$(sed -E 's/ $//' "$STUB_LOG" | grep -vE '^install.sh --system' | tr '\n' '|')" "cutover order"
assert_contains "$S" "backup=$STUB_BACKUP"
assert_contains "$F/out" "reboot now"

rc=0; STUB_UNINSTALL_CURRENT_RC=4 cut || rc=$?
assert_eq 4 "$rc" "cutover stops at the first failure"
assert_absent "$S"
grep -q '^install.sh' "$STUB_LOG" && fail "install ran after a failed uninstall"
assert_contains "$F/out" "cutover failed at uninstall-current.sh"

rc=0; STUB_UNINSTALL_CURRENT_RC=9 cut || rc=$?
assert_eq 0 "$rc" "cutover resumes after HyDE was moved"
grep -q '^install.sh' "$STUB_LOG" || fail "resume runs install"
assert_contains "$S" "backup=$STUB_BACKUP"

rc=0; STUB_INSTALL_RC=6 cut || rc=$?
assert_eq 6 "$rc" "cutover stops when the system step fails"
assert_absent "$S"
assert_contains "$F/out" "run ./rollback.sh"

mkdir -p "$F/bk/20990101-000000" "$F/bk/20980101-000000"
roll() { : > "$STUB_LOG"; "$FX/rollback.sh" "$@" > "$F/out" 2>&1; }
mkdir -p "$(dirname "$S")"; echo "backup=$F/bk/20980101-000000" > "$S"
rc=0; roll || rc=$?
assert_eq 0 "$rc" "rollback succeeds"
assert_eq "sudo $FX/install.sh --system --undo|sudo $FX/backup/restore.sh $F/bk/20980101-000000 --torus $FX|" "$(grep '^sudo' "$STUB_LOG" | tr '\n' '|')" "rollback uses the recorded backup"
assert_absent "$S"

rc=0; roll || rc=$?
assert_eq 2 "$rc" "rollback without a recorded cutover needs --backup"
grep -q 'restore.sh' "$STUB_LOG" && fail "restore ran without a recorded cutover"
rc=0; roll --backup "$F/bk/20980101-000000" || rc=$?
grep -q "restore.sh $F/bk/20980101-000000" "$STUB_LOG" || fail "rollback --backup overrides"

echo "backup=$F/bk/20980101-000000" > "$S"
rc=0; STUB_RESTORE_RC=7 roll || rc=$?
assert_eq 0 "$rc" "restore rc 7 is success"
assert_contains "$F/out" "missing"
assert_absent "$S"

echo "backup=$F/bk/20980101-000000" > "$S"
rc=0; STUB_INSTALL_RC=10 roll || rc=$?
assert_eq 0 "$rc" "undo with nothing to undo is fine"

echo "backup=$F/bk/20980101-000000" > "$S"
rc=0; STUB_INSTALL_RC=6 roll || rc=$?
assert_eq 6 "$rc" "rollback stops when undo fails"
[[ -f $S ]] || fail "state kept after a failed rollback"
grep -q 'restore.sh' "$STUB_LOG" && fail "restore ran after a failed undo"

echo ok
