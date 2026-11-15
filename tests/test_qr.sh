#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/run"
export PATH=$F/bin:$PATH XDG_RUNTIME_DIR=$F/run STUB_LOG=$F/calls
cat > "$F/bin/qrencode" <<'S'
#!/usr/bin/env bash
while [[ $# -gt 0 ]]; do [[ $1 == -o ]] && { out=$2; shift; }; shift; done
cat > "$out"
S
cat > "$F/bin/nmcli" <<'S'
#!/usr/bin/env bash
echo "nmcli $*" >> "$STUB_LOG"
case "$*" in
  "-g UUID,TYPE connection show --active") printf 'u-eth:802-3-ethernet\nu-home:802-11-wireless\nu-open:802-11-wireless\n' ;;
  "-g 802-11-wireless.ssid connection show u-home") printf '%s\n' "${STUB_SSID:-Home;Net}" ;;
  "-g 802-11-wireless.ssid connection show u-open") echo "Cafe" ;;
  "-g 802-11-wireless-security.key-mgmt connection show u-home") echo "wpa-psk" ;;
  "-g 802-11-wireless-security.key-mgmt connection show u-open") echo "" ;;
  "-s -g 802-11-wireless-security.psk connection show u-home") printf '%s\n' "${STUB_PSK-pa:ss\\w,rd\"}" ;;
esac
S
chmod +x "$F/bin/"*
Q=$REPO/home/.local/bin/torus-qr

r=$("$Q" text -- "hello world")
[[ $r == "ok $F/run/torus-qr-"*.png ]] || fail "text: [$r]"
assert_eq "hello world" "$(cat "${r#ok }")" "text: the payload is the entry as is"
r2=$("$Q" text -- "second")
[[ ! -e ${r#ok } ]] || fail "text: an older code is cleaned up"
assert_eq "too-long" "$("$Q" text -- "$(head -c 2001 /dev/zero | tr '\0' x)")" "over 2000 bytes"
assert_eq "too-long" "$("$Q" text -- "$(printf 'ü%.0s' $(seq 1001))")" "the limit counts bytes, not characters"
r=$("$Q" text -- "$(head -c 2000 /dev/zero | tr '\0' x)"); [[ $r == ok* ]] || fail "exactly 2000 bytes fits"
assert_eq "empty" "$("$Q" text -- "")" "empty text"

r=$("$Q" wifi "Home;Net")
assert_eq 'WIFI:T:WPA;S:Home\;Net;P:pa\:ss\\w\,rd\";;' "$(cat "${r#ok }")" "wifi: WPA payload with escaping"
r=$("$Q" wifi "Cafe")
assert_eq 'WIFI:T:nopass;S:Cafe;;' "$(cat "${r#ok }")" "wifi: open network"
assert_eq "not-connected" "$("$Q" wifi "Elsewhere")" "wifi: not the connected network"
assert_eq "no-password" "$(STUB_PSK= "$Q" wifi "Home;Net")" "wifi: secret not stored"
grep -q -- '-s -g 802-11-wireless-security.psk' "$STUB_LOG" || fail "wifi: password read with nmcli -s"
mkdir -p "$F/bare"
for c in bash env sed wc rm; do ln -s "$(command -v "$c")" "$F/bare/$c"; done
assert_eq "missing" "$(PATH=$F/bare "$Q" text -- hi)" "qrencode missing"
assert_eq "error" "$(env -u XDG_RUNTIME_DIR "$Q" text -- hi)" "no runtime dir: no code written to /tmp"
echo "qr: ok"
