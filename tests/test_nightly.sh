#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/vm" "$F/bin" "$F/vms" "$F/state" "$F/cache" "$F/repo"
cp "$REPO/vm/nightly.sh" "$F/vm/"
export PATH=$F/bin:$PATH XDG_STATE_HOME=$F/state XDG_CACHE_HOME=$F/cache TORUS_VM_DIR=$F/vms TORUS_NIGHTLY_REPO=$F/repo LOG=$F/calls
git -C "$F/repo" init -q -b polish && git -C "$F/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
cat > "$F/vm/torus-vm" <<'S'
#!/usr/bin/env bash
echo "torus-vm $1" >> "$LOG"
case $1 in
  ssh) [[ $* == *parity.sh* ]] && { cat > /dev/null; printf 'binds: ok\n%s\nparity: %s\n' "${STUB_FAIL:-bar: ok}" "${STUB_SCORE:-48/48}"; }; [[ $* == *isLocked* ]] && echo false; exit 0 ;;
  push) exit 0 ;;
esac
exit 0
S
printf '#!/bin/sh\nexit 0\n' > "$F/vm/qmp-keys.py"; cp "$F/vm/qmp-keys.py" "$F/vm/qmp-text.py"
printf '#!/bin/sh\n[ "$1" = "-eo" ] && echo "${STUB_PROCS:-bash}"\n' > "$F/bin/ps"
printf '#!/bin/sh\nexit 1\n' > "$F/bin/pgrep"
chmod +x "$F"/vm/* "$F"/bin/*
N=$F/vm/nightly.sh
line() { cut -f2,3 "$F/state/torus/parity-nightly"; }

"$N" > /dev/null
assert_eq "skipped	no dev VM" "$(line)" "no VM image, nothing booted"
touch "$F/vms/dev.qcow2" "$F/vms/password"
STUB_PROCS=cs2 "$N" > /dev/null
assert_eq "skipped	a game was running" "$(line)" "never during a game"
grep -q "torus-vm start" "$LOG" 2> /dev/null && fail "VM booted while gaming"
"$N" > /dev/null
assert_eq "ok	48/48 on polish@$(git -C "$F/repo" rev-parse --short HEAD)" "$(line)" "a green run is recorded"
grep -q "torus-vm down" "$LOG" || fail "VM shut down after the run"
STUB_FAIL="lock: FAIL no-lock" STUB_SCORE=47/48 "$N" > /dev/null || true
assert_eq "fail	47/48 on polish@$(git -C "$F/repo" rev-parse --short HEAD), failed: lock " "$(line)" "failures are named"
[[ -n $(ls "$F/cache/torus/nightly/"*.log) ]] || fail "log written"
echo "nightly: ok"
