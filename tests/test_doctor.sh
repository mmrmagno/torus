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
unset HYPRLAND_INSTANCE_SIGNATURE
export HOME=$F/home XDG_RUNTIME_DIR=$F/run XDG_STATE_HOME=$F/state XDG_CACHE_HOME=$F/cache STUB_LOG=$F/calls PATH=$F/bin:$PATH
mkdir -p "$HOME/.config/x" "$HOME/.local/bin"
ln -s "$R/home/.config/x/a.conf" "$HOME/.config/x/a.conf"
ln -s "$R/home/.local/bin/torus-doctor" "$HOME/.local/bin/torus-doctor"

stub() { printf '#!/usr/bin/env bash\necho "%s $*" >> "$STUB_LOG"\n%s\n' "$1" "$2" > "$F/bin/$1"; chmod +x "$F/bin/$1"; }
stub systemctl 'case "$*" in *"is-active --quiet torus-shell.service") [[ -z ${STUB_SHELL_DOWN:-} ]] || grep -q "start torus-shell" "$STUB_LOG"; exit $? ;; *"is-active"*) exit 1 ;; *"cat torus-shell-rescue.service") exit 0 ;; *"show -p MainPID"*) echo "${STUB_PID:-}" ;; esac; exit 0'
stub qs 'n=$(awk "/start torus-shell/ { f = 1; next } f && /^qs/ { c++ } END { print c + 0 }" "$STUB_LOG"); if [[ -n ${STUB_LOCKED_AFTER:-} ]] && ((n > STUB_LOCKED_AFTER)); then echo true; else echo "${STUB_LOCKED:-false}"; fi'
stub pgrep 'case "$*" in *hypridle*) exit 0 ;; *hyprlock*) [[ -n ${STUB_HYPRLOCK_AFTER:-} ]] && grep -q "restart torus-shell" "$STUB_LOG" ;; *) exit 1 ;; esac'
stub hyprlock 'exit 0'
stub pacman 'exit 0'
stub journalctl '[[ -n ${STUB_LOADED:-} && $* == *short-unix* ]] && echo "$STUB_LOADED.5 host sh[7]: INFO: Configuration Loaded"; [[ -n ${STUB_RELOAD_FAILS:-} ]] && echo " ERROR: Failed to load configuration"; exit 0'
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

mkdir -p "$XDG_RUNTIME_DIR/torus-lock"; echo old-login > "$XDG_RUNTIME_DIR/torus-lock/locked"
out=$("$D") && fail "a stale lock marker must fail"
grep -q 'earlier login' <<< "$out" || fail "stale marker named: $out"
"$D" --fix > /dev/null || true
[[ ! -e $XDG_RUNTIME_DIR/torus-lock/locked ]] || fail "fix removes the stale marker"

echo sig > "$XDG_RUNTIME_DIR/torus-lock/locked"
out=$("$D") && fail "a lock nobody draws must fail"
grep -q 'purple screen' <<< "$out" || fail "purple screen named: $out"
STUB_LOCKED=true "$D" > /dev/null || fail "a held shell lock is fine"
: > "$STUB_LOG"
out=$(TORUS_RELOCK_TRIES=2 "$D" --fix) || true
grep -q 'restart torus-shell.service' "$STUB_LOG" || fail "fix restarts the shell to lock again"
grep -q '^hyprlock' "$STUB_LOG" || fail "hyprlock takes over when the shell does not lock: $(cat "$STUB_LOG")"
grep -q 'hyprlock took over' <<< "$out" || fail "takeover reported: $out"
[[ -e $XDG_RUNTIME_DIR/torus-lock/locked ]] || fail "fix never drops the marker of this login"
: > "$STUB_LOG"
out=$(STUB_LOCKED_AFTER=1 TORUS_RELOCK_TRIES=2 "$D" --fix) || true
grep -q 'holds the lock again' <<< "$out" || fail "shell relock reported: $out"
grep -q '^hyprlock' "$STUB_LOG" && fail "no hyprlock when the shell locked again"
: > "$STUB_LOG"
out=$(STUB_SHELL_DOWN=1 STUB_LOCKED_AFTER=1 TORUS_RELOCK_TRIES=2 "$D" --fix) || true
assert_eq 1 "$(grep -c 'start torus-shell' "$STUB_LOG")" "a stopped shell is started once, never restarted on top"
grep -q 'holds the lock again' <<< "$out" || fail "started shell relock reported: $out"
: > "$STUB_LOG"
out=$(STUB_HYPRLOCK_AFTER=1 TORUS_RELOCK_TRIES=2 "$D" --fix) || true
grep -q 'hyprlock holds the lock' <<< "$out" || fail "a hyprlock that took over counts: $out"
grep -q '^hyprlock' "$STUB_LOG" && fail "no second hyprlock next to a running one"
rm -f "$XDG_RUNTIME_DIR/torus-lock/locked"

mkdir -p "$XDG_CACHE_HOME/torus/crashes"; : > "$XDG_CACHE_HOME/torus/crashes/x.log"
out=$("$D") || fail "a crash is a warning, not a failure: $out"
grep -q '1 shell crash' <<< "$out" || fail "recent crash noted: $out"
rm -rf "$XDG_CACHE_HOME/torus/crashes"

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

mkdir -p "$HOME/.config/quickshell/torus"
echo x > "$HOME/.config/quickshell/torus/a.qml"
touch -d "@2000000000" "$HOME/.config/quickshell/torus/a.qml"
out=$(STUB_PID=7 STUB_LOADED=1900000000 "$D") || true
grep -q 'runs older code' <<< "$out" || fail "stale shell noticed: $out"
: > "$STUB_LOG"
STUB_PID=7 STUB_LOADED=1900000000 "$D" --fix > /dev/null || true
grep -q 'qs -c torus ipc call torus reload' "$STUB_LOG" || fail "fix reloads the shell"
out=$(STUB_PID=7 STUB_LOADED=2000000100 "$D") || true
grep -q 'runs the code in the repo' <<< "$out" || fail "a fresh load is fine: $out"
grep -q 'torus-doctor" --reload-shell' "$REPO/install.sh" || fail "install reloads the shell"
: > "$STUB_LOG"
assert_eq reloaded "$(TORUS_RELOAD_WAIT=0 "$D" --reload-shell)" "a clean reload stays a reload"
grep -q 'ipc call torus reload' "$STUB_LOG" || fail "reload goes over IPC"
grep -q 'restart torus-shell' "$STUB_LOG" && fail "no restart after a clean reload"
: > "$STUB_LOG"
assert_eq restarted "$(STUB_RELOAD_FAILS=1 TORUS_RELOAD_WAIT=0 "$D" --reload-shell)" "a failed reload falls back to a restart"
grep -q 'restart torus-shell' "$STUB_LOG" || fail "restart after a failed reload"
grep -q 'torus-reload' "$REPO/install.sh" || fail "install reloads Hyprland, git replaces binds.lua without it noticing"
