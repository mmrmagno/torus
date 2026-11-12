#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/v"
export TORUS_VM_DIR=$F/v PATH=$F/bin:$PATH LOG=$F/calls
for c in qemu-img swtpm qemu-system-x86_64 nice taskset ssh; do printf '#!/bin/sh\necho "%s $*" >> "$LOG"\n' "$c" > "$F/bin/$c"; done
printf '#!/bin/sh\necho "qemu-img $*" >> "$LOG"\n[ "$1" = create ] && touch "${!#}"\nexit 0\n' > "$F/bin/qemu-img"
chmod +x "$F"/bin/*
T=$REPO/vm/torus-vm
echo image > "$F/v/dev-golden.qcow2"; : > "$F/v/dev-golden.vars.fd"; chmod 444 "$F/v/dev-golden.qcow2"
echo mine > "$F/v/dev.qcow2"
assert_fails "$T" up dev --from dev-golden
assert_eq mine "$(cat "$F/v/dev.qcow2")" "up refuses to wipe an existing overlay"
out=$("$T" up dev --from dev-golden 2>&1 || true)
grep -q "start dev" <<< "$out" || fail "up says to use start: $out"
"$T" rebuild dev > /dev/null 2>&1 || true
kept=$(ls "$F"/v/dev-lost-*.qcow2 2> /dev/null | head -1)
[[ -n $kept && $(cat "$kept") == mine ]] || fail "rebuild keeps the old overlay aside: $(ls "$F/v")"
grep -q "qemu-img create -q -f qcow2 -b $F/v/dev-golden.qcow2" "$LOG" || fail "rebuild starts from dev-golden: $(cat "$LOG")"
assert_fails "$T" rm dev-golden
[[ -e $F/v/dev-golden.qcow2 ]] || fail "frozen image kept"
echo "torus-vm: ok"
