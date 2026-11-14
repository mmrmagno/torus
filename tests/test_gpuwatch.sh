#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/state"
export PATH=$F/bin:$PATH XDG_STATE_HOME=$F/state LOG=$F/calls
G=$REPO/home/.local/bin/torus-gpuwatch
X=$REPO/tests/fixtures/gpu/night.log

out=$("$G" replay "$X")
assert_eq 2 "$(wc -l <<< "$out")" "one event per reset"
assert_eq "cs2:false:1" "$(sed -n 1p <<< "$out" | jq -r '"\(.culprit):\(.encoder):\(.resets)"')" "first reset names the game"
assert_eq "Counter-Strike 2 froze the GPU and the driver reset it. A reboot gives a clean GPU." "$(sed -n 1p <<< "$out" | jq -r .text)" "plain words"
assert_eq "gpu-screen-reco:true:2" "$(sed -n 2p <<< "$out" | jq -r '"\(.culprit):\(.encoder):\(.resets)"')" "the recorder, from the ring line, not the page fault"
grep -q "game clips are off" <<< "$(sed -n 2p <<< "$out" | jq -r .text)" || fail "says clips are off after an encoder hang"

printf '#!/usr/bin/env bash\necho "notify-send $*" >> "$LOG"\n[[ -n ${STUB_PICK:-} ]] && echo "$STUB_PICK"\nexit 0\n' > "$F/bin/notify-send"
printf '#!/usr/bin/env bash\necho "qs $*" >> "$LOG"\n' > "$F/bin/qs"
cat > "$F/bin/journalctl" <<S
#!/usr/bin/env bash
[[ \$* == *" -f "* ]] && { [[ -n \${STUB_LIVE:-} ]] && cat "$X" | sed -n 1,4p | sed 's/reset(1)/reset(3)/'; exit 0; }
cat "$X"
S
chmod +x "$F/bin"/*

timeout 10 "$G" follow > "$F/out" || true
sleep 0.3
assert_eq 1 "$(grep -c '^notify-send' "$LOG")" "one notification for what happened earlier this boot"
grep -q 'GPU reset (2 this boot)' "$LOG" || fail "title counts the resets: $(cat "$LOG")"
grep -q 'that is why the session restarted' "$LOG" || fail "explains the restart: $(cat "$LOG")"
grep -q -- '-A reboot=Reboot now -A later=Later' "$LOG" || fail "two actions"
: > "$LOG"
timeout 10 "$G" follow > /dev/null || true
assert_eq 0 "$(grep -c '^notify-send' "$LOG" || true)" "the same resets are never announced twice in a boot"
STUB_LIVE=1 STUB_PICK=reboot timeout 15 "$G" follow > /dev/null || true
sleep 0.5
assert_eq 1 "$(grep -c '^notify-send' "$LOG")" "a new reset while running is announced once"
grep -q 'qs -c torus ipc call torus logoutToggle' "$LOG" || fail "Reboot now opens the logout menu (it asks), it never reboots by itself"
grep -v '^notify-send' "$LOG" | grep -qiE 'reboot|poweroff' && fail "never reboots by itself"
assert_fails "$G" nonsense
echo "gpuwatch: ok"
