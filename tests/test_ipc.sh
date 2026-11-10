#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export STUB_LOG=$F/calls PATH=$F/bin:$PATH
mkdir -p "$F/bin"
cat > "$F/bin/qs" <<'S'
#!/usr/bin/env bash
echo "qs $*" >> "$STUB_LOG"
case "$*" in
  *"ipc show") printf 'target torus\n  function lock(): string\n  function aiAsk(text: string): void\n' ;;
  *"call torus lock") printf '  WARN: Detected locale "C"\nQt depends on a UTF-8 locale\nlocked\n' ;;
esac
S
chmod +x "$F/bin/qs"
I=$REPO/home/.local/bin/torus-ipc

out=$("$I")
grep -qE '^  aiAsk +text: string *$' <<< "$out" || fail "list shows arguments: $out"
grep -qE '^  lock +-> string$' <<< "$out" || fail "list shows return type: $out"
assert_eq "aiAsk lock" "$("$I" --names | tr '\n' ' ' | sed 's/ $//')" "names for completion"
assert_eq locked "$("$I" lock)" "call output without the locale noise"
"$I" aiAsk "hello there" > /dev/null
grep -q '^qs -c torus ipc call torus aiAsk hello there$' "$STUB_LOG" || fail "arguments passed through"
"$I" nope 2> /dev/null && fail "unknown function refused"
true
