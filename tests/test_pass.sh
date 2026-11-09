#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin"
export STUB_LOG=$F/calls CLIP=$F/clip
cat > "$F/bin/pass-cli" <<'S'
#!/usr/bin/env bash
echo "pass-cli $*" >> "$STUB_LOG"
[[ -n ${STUB_LOCKED:-} ]] && { echo "Error: This operation requires an authenticated client" >&2; exit 1; }
case "$1 $2" in
  "vault list") printf -- '- [SID_A==]: Personal\n- [SID_B==]: Work Stuff\n' ;;
  "item list")
    [[ $4 == SID_A== ]] && printf -- '- [IID_1==]: github.com (state=Active)\n- [IID_2==]: Steam (old) (state=Active)\n- [IID_9==]: deleted.com (state=Trashed)\n'
    [[ $4 == SID_B== ]] && printf -- '- [IID_3==]: vpn.example.org (state=Active)\n'
    ;;
  "item view")
    case "$*" in
      *"--field password"*) echo "s3cret-xyz" ;;
      *"--field private_key"*) [[ $6 == IID_K== ]] && echo "-----BEGIN KEY-----" || { echo "Error: Field does not exist" >&2; exit 1; } ;;
      *"--field email"*) echo "me@example.org" ;;
      *) echo "Error: Field does not exist: username" >&2; exit 1 ;;
    esac ;;
  "item totp") [[ -n ${STUB_NO_TOTP:-} ]] && { echo "Error: no TOTP" >&2; exit 1; }; printf 'totp: 123456\n' ;;
esac
S
printf '#!/usr/bin/env bash\necho "wl-copy $*" >> "$STUB_LOG"\nif [[ $1 == --clear ]]; then : > "$CLIP"; else cat > "$CLIP"; fi\n' > "$F/bin/wl-copy"
printf '#!/usr/bin/env bash\ncat "$CLIP" 2>/dev/null\n' > "$F/bin/wl-paste"
printf '#!/usr/bin/env bash\necho "notify-send $*" >> "$STUB_LOG"\n' > "$F/bin/notify-send"
printf '#!/usr/bin/env bash\necho "qs $*" >> "$STUB_LOG"\n' > "$F/bin/qs"
chmod +x "$F/bin"/*
export PATH=$F/bin:$PATH
T=$REPO/home/.local/bin/torus-pass

out=$("$T" list)
assert_eq "$(printf 'SID_A==\tIID_1==\tPersonal\tgithub.com\nSID_A==\tIID_2==\tPersonal\tSteam (old)\nSID_B==\tIID_3==\tWork Stuff\tvpn.example.org')" "$out" "list: names only, ids, vault"
grep -q -- '--output\|--show-secrets\|item view' "$STUB_LOG" && fail "list must never view items or ask for json"

: > "$STUB_LOG"
"$T" copy SID_A== IID_1== password 1
assert_eq "" "$(cat "$CLIP")" "clipboard cleared after the timeout"
grep -q '^wl-copy --sensitive' "$STUB_LOG" || fail "copy marks the clipboard sensitive"
grep -q '^qs .*islandFlash' "$STUB_LOG" || fail "island told"
grep -q 's3cret' "$STUB_LOG" && fail "secret leaked into a command line"

: > "$STUB_LOG"
"$T" copy SID_A== IID_1== totp 1 &
sleep 0.5
assert_eq 123456 "$(cat "$CLIP")" "totp code copied"
wait

: > "$STUB_LOG"; : > "$CLIP"
rc=0; "$T" copy SID_A== IID_1== username 0 || rc=$?
assert_eq 1 "$rc" "missing field exits 1"
grep -q '^notify-send .*no username' "$STUB_LOG" || fail "missing field notifies"
grep -q '^wl-copy' "$STUB_LOG" && fail "missing field copies nothing"

echo "kept" > "$CLIP"
( sleep 0.3; echo "something else" > "$CLIP" ) &
"$T" copy SID_A== IID_1== email 1
wait
assert_eq "something else" "$(cat "$CLIP")" "a newer copy is never cleared"

: > "$STUB_LOG"
assert_eq "$(printf 'password\nemail\ntotp')" "$("$T" fields SID_A== IID_1==)" "fields: only the ones the item has"
grep -q 's3cret\|me@example' "$STUB_LOG" && fail "fields must not log values"
assert_eq "$(printf 'password\nemail\nprivate_key\ntotp')" "$("$T" fields SID_A== IID_K==)" "fields: ssh key field found"
STUB_NO_TOTP=1 assert_eq "$(printf 'password\nemail')" "$(STUB_NO_TOTP=1 "$T" fields SID_A== IID_1==)" "fields: no totp when the item has none"

rc=0; STUB_LOCKED=1 "$T" list > "$F/locked" 2>&1 || rc=$?
assert_eq 3 "$rc" "locked pass-cli exits 3"
true
