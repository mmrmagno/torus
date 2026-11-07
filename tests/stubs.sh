mkstubs() {
  local b=$1
  mkdir -p "$b"
  cat > "$b/pacman" <<'S'
#!/usr/bin/env bash
echo "pacman $*" >> "$STUB_LOG"
case "$*" in
  "-Qqen") printf 'base\nghost-pkg\n' ;;
  "-Qqem") printf 'yay\nyay-debug\n' ;;
  "-Qii") ;;
  "-Qq chaotic-keyring") exit 1 ;;
  "-Slq") printf 'base\nchaotic-keyring\n' ;;
  "--config "*" -U "*)
    grep -q '^\[chaotic-aur\]' "$2" && { echo "pacman -U config-has-chaotic" >> "$STUB_LOG"; exit 1; } ;;
  *ghost-pkg*) exit 1 ;;
esac
exit 0
S
  cat > "$b/systemctl" <<'S'
#!/usr/bin/env bash
echo "systemctl $*" >> "$STUB_LOG"
[[ -n ${STUB_ENABLE_FAIL:-} && $1 == enable ]] && exit 1
case "$*" in
  "list-unit-files --state=enabled --no-legend") echo "sddm.service enabled enabled" ;;
  "--user list-unit-files --state=enabled --no-legend") echo "pipewire.socket enabled enabled" ;;
  "--user list-unit-files --state=masked --no-legend")
    [[ -n ${STUB_NO_MASKED:-} ]] && exit 1
    echo "dunst.service masked masked" ;;
esac
exit 0
S
  cat > "$b/flatpak" <<'S'
#!/usr/bin/env bash
echo "flatpak $*" >> "$STUB_LOG"
[[ $1 == list ]] && echo "org.gimp.GIMP"
exit 0
S
  cat > "$b/dconf" <<'S'
#!/usr/bin/env bash
echo "dconf $*" >> "$STUB_LOG"
[[ $1 == dump ]] && echo "[org/test]"
exit 0
S
  cat > "$b/sbctl" <<'S'
#!/usr/bin/env bash
echo "sbctl $*" >> "$STUB_LOG"
if [[ $1 == verify ]]; then
  echo "✗ /boot/grub/x86_64-efi/core.efi is not signed"
  for i in $(seq 200); do echo "✓ /boot/padding-$i.efi is signed"; done
  if [[ -n ${STUB_UNSIGNED:-} ]]; then echo "✗ /boot/vmlinuz-linux is not signed"; else echo "✓ /boot/vmlinuz-linux is signed"; fi
fi
exit 0
S
  local c
  cat > "$b/pacman-key" <<'S'
#!/usr/bin/env bash
echo "pacman-key $*" >> "$STUB_LOG"
[[ $1 == --populate ]] && exit 0
[[ $1 == --config && -f $2 ]] || { echo "pacman-key config-missing" >> "$STUB_LOG"; exit 1; }
grep -q '^\[chaotic-aur\]' "$2" && { echo "pacman-key config-has-chaotic" >> "$STUB_LOG"; exit 1; }
echo "pacman-key config-clean" >> "$STUB_LOG"
exit 0
S
  for c in yay grub-mkconfig mkinitcpio gsettings; do
    printf '#!/usr/bin/env bash\necho "%s $*" >> "$STUB_LOG"\nexit 0\n' "$c" > "$b/$c"
  done
  printf '#!/usr/bin/env bash\nexit 1\n' > "$b/crontab"
  chmod +x "$b"/*
}
