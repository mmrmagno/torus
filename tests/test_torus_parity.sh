#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/run/hypr/sig"
export XDG_RUNTIME_DIR=$F/run PATH=$F/bin:$PATH STATE=$F/open TORUS_PARITY_WAIT=0 TORUS_PARITY_NO_KEYS=1
: > "$STATE"
cat > "$F/bin/qs" <<'S'
#!/usr/bin/env bash
shift 5
case $1 in
  isLocked) echo false ;;
  isOpen) grep -qx "$2" "$STATE" && echo true || echo false ;;
  *Toggle)
    n=${1%Toggle}; n=${n/cheatSheet/cheatsheet}
    [[ $n == ${STUB_STUCK:-none} ]] && { echo "$n" >> "$STATE"; exit 0; }
    if grep -qx "$n" "$STATE"; then sed -i "/^$n\$/d" "$STATE"; else echo "$n" >> "$STATE"; fi ;;
esac
S
cat > "$F/bin/hyprctl" <<'S'
#!/usr/bin/env bash
case $1 in
  binds) jq -n '[{modmask: 64, key: "D", release: false}]' ;;
  configerrors) echo "" ;;
  version) echo '{"tag":"v0.57.2"}' ;;
esac
S
printf '#!/bin/sh\nexit 0\n' > "$F/bin/setsid"
printf '#!/bin/sh\necho %s\n' "'[{\"type\":\"PipeWire:Interface:Node\",\"info\":{\"props\":{\"media.class\":\"Stream/Output/Audio\",\"application.name\":\"pw-play\"}}}]'" > "$F/bin/pw-dump"
printf '#!/bin/sh\necho alsa_output.test\n' > "$F/bin/pactl"
printf '#!/bin/sh\n[ -n "$STUB_JOURNAL" ] && printf "%%b" "$STUB_JOURNAL"\nexit 0\n' > "$F/bin/journalctl"
printf '#!/bin/sh\necho inv\n' > "$F/bin/systemctl"
chmod +x "$F"/bin/*
R=$F/repo; mkdir -p "$R/home/.local/bin" "$R/tests"
cp "$REPO/home/.local/bin/torus-parity" "$R/home/.local/bin/"
mkdir -p "$R/home/.local/share/torus"; cp "$REPO/home/.local/share/torus/checks.sh" "$R/home/.local/share/torus/"
echo "SUPER+D" > "$R/tests/binds.expected"
P=$R/home/.local/bin/torus-parity
out=$("$P") || fail "healthy machine fails: $out"
grep -q "ok    panels     12 panels open and close" <<<"$out" || fail "panels line: $out"
grep -q "skip  esc" <<<"$out" || fail "esc skipped without a keyboard: $out"
grep -q "ok    sound" <<<"$out" || fail "sound: $out"
[[ ! -s $STATE ]] || fail "panels left open: $(cat "$STATE")"
out=$(STUB_STUCK=network "$P") && fail "a panel that does not close must fail"
grep -q "network(close)" <<<"$out" || fail "stuck panel named: $out"
: > "$STATE"
out=$(STUB_JOURNAL=' ERROR: Failed to load configuration\n INFO: Configuration Loaded\n' "$P") || fail "an error before the last successful load is history: $out"
out=$(STUB_JOURNAL=' INFO: Configuration Loaded\n WARN qml: Foo.qml:3: TypeError: x\n' "$P") && fail "a warning after the last load must fail"
grep -q "TypeError" <<<"$out" || fail "the warning is named: $out"
echo "SUPER+X" >> "$R/tests/binds.expected"
out=$("$P") && fail "a missing bind must fail"
grep -q "missing: SUPER+X" <<<"$out" || fail "missing bind named: $out"
echo "torus-parity: ok"
