#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
R=$F/repo
mkdir -p "$R/home/.local/bin" "$R/home/.config/x" "$R/packages" "$F/bin" "$F/home" "$F/run/hypr/sig" "$F/state/torus"
cp "$REPO/home/.local/bin/torus-doctor" "$R/home/.local/bin/"
echo a > "$R/home/.config/x/a.conf"
echo pkg-a > "$R/packages/native.txt"; : > "$R/packages/aur.txt"
export HOME=$F/home XDG_RUNTIME_DIR=$F/run XDG_STATE_HOME=$F/state XDG_CACHE_HOME=$F/cache STUB_LOG=$F/calls PATH=$F/bin:$PATH
mkdir -p "$HOME/.config/x" "$HOME/.local/bin"
ln -s "$R/home/.config/x/a.conf" "$HOME/.config/x/a.conf"
ln -s "$R/home/.local/bin/torus-doctor" "$HOME/.local/bin/torus-doctor"

stub() { printf '#!/usr/bin/env bash\necho "%s $*" >> "$STUB_LOG"\n%s\n' "$1" "$2" > "$F/bin/$1"; chmod +x "$F/bin/$1"; }
stub systemctl 'case "$*" in *"is-active --quiet torus-shell.service") exit 0 ;; *"is-active"*) exit 1 ;; *"cat torus-shell-rescue.service") exit 0 ;; esac; exit 0'
stub qs 'echo "${STUB_LOCKED:-false}"'
stub pgrep 'case "$*" in *hypridle*) exit 0 ;; *hyprlock*) exit 1 ;; esac; exit 1'
stub hyprlock 'exit 0'
stub pacman 'exit 0'
stub journalctl 'exit 0'
cat > "$F/bin/hyprctl" <<'S'
#!/usr/bin/env bash
echo "hyprctl $*" >> "$STUB_LOG"
case "$1" in
  monitors) [[ -n ${STUB_MONITORS:-} ]] && echo "$STUB_MONITORS" || echo '[{"name":"DP-1","x":0,"y":0},{"name":"DP-2","x":2560,"y":0}]' ;;
  activewindow) echo '{"class":"kitty","fullscreen":0}' ;;
  configerrors) echo "${STUB_CONFIGERR:-}" ;;
  *) echo '{}' ;;
esac
S
chmod +x "$F/bin/hyprctl"
D=$HOME/.local/bin/torus-doctor

out=$("$D") || fail "healthy setup reports problems: $out"
grep -q 'ok    screens' <<< "$out" || fail "screens check: $out"

out=$(STUB_MONITORS='[{"name":"DP-1","x":0,"y":0},{"name":"DP-2","x":102560,"y":0}]' "$D") && fail "a stranded screen must fail"
grep -q 'DP-2 moved away' <<< "$out" || fail "stranded screen named: $out"
printf 'DP-2\t2560\t410\n' > "$XDG_STATE_HOME/torus/gameguard-moat"
STUB_MONITORS='[{"name":"DP-2","x":102560,"y":0}]' "$D" --fix > /dev/null || true
grep -q 'hyprctl eval hl.monitor({ output = "DP-2", position = "2560x410" })' "$STUB_LOG" || fail "fix puts the screen back"
[[ ! -e $XDG_STATE_HOME/torus/gameguard-moat ]] || fail "fix clears the saved moat"

mkdir -p "$XDG_RUNTIME_DIR/torus-lock"; : > "$XDG_RUNTIME_DIR/torus-lock/locked"
out=$("$D") && fail "a stale lock marker must fail"
grep -q 'nothing holds the lock' <<< "$out" || fail "stale marker named: $out"
STUB_LOCKED=true "$D" > /dev/null || fail "a held shell lock is fine"
"$D" --fix > /dev/null || true
[[ ! -e $XDG_RUNTIME_DIR/torus-lock/locked ]] || fail "fix removes the stale marker"

out=$(STUB_CONFIGERR='error at binds.lua:3' "$D") && fail "config errors must fail"
grep -q 'binds.lua:3' <<< "$out" || fail "config error shown: $out"

echo b > "$R/home/.config/x/b.conf"
out=$("$D") && fail "a missing link must fail"
grep -q '1 missing' <<< "$out" || fail "missing link counted: $out"
"$D" --fix > /dev/null || true
[[ $(readlink "$HOME/.config/x/b.conf") == "$R/home/.config/x/b.conf" ]] || fail "fix links the missing file"

echo '{broken' > "$XDG_STATE_HOME/torus/x.json"
out=$("$D") && fail "broken JSON must fail"
grep -q 'invalid JSON: x.json' <<< "$out" || fail "broken JSON named: $out"
rm "$XDG_STATE_HOME/torus/x.json"

snap=$("$D" --snapshot)
[[ -d $snap && -f $snap/monitors.json && -f $snap/doctor.txt ]] || fail "snapshot files"
assert_eq 700 "$(stat -c %a "$snap")" "snapshot is private"
