#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export XDG_STATE_HOME=$F/state TORUS_FETCH_SHAPE=torus
mkdir -p "$F/bin"
cat > "$F/bin/fastfetch" <<'S'
#!/usr/bin/env bash
echo "fastfetch $*" >> "$STUB_LOG"
if [[ " $* " == *" --logo none "* ]]; then printf 'marc @ os\nos : Arch Linux\nkernel : 7.2\n'; else echo plain-fastfetch; fi
S
chmod +x "$F/bin/fastfetch"
export STUB_LOG=$F/calls PATH=$F/bin:$PATH
T=$REPO/home/.local/bin/torus-fetch

out=$("$T" < /dev/null)
assert_eq plain-fastfetch "$out" "no terminal means plain fastfetch"

TORUS_FETCH_FORCE=1 TORUS_FETCH_FRAMES=5 COLUMNS=120 "$T" > "$F/anim" < /dev/null
plain=$(sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\r//g' "$F/anim")
assert_eq 5 "$(grep -c 'marc @ os' <<< "$plain")" "info drawn once per frame"
tail -n 20 <<< "$plain" | cut -c1-40 | sed 's/ *$//' > "$F/last"
deno run --quiet --allow-read --allow-write "$REPO/donut/render-logo.ts" "$F/ff" > /dev/null
perl -pe 's/\$(\$|[1-9])/$1 eq "\$" ? "\$" : ""/ge' "$F/ff/logo.txt" | sed 's/ *$//' > "$F/logo"
diff "$F/logo" "$F/last" > /dev/null || fail "animation does not end on the static logo: $(diff "$F/logo" "$F/last" | head -4)"
grep -q $'\x1b\[?25h' "$F/anim" || fail "cursor not shown again"
grep -q $'\x1b\[?7l' "$F/anim" || fail "line wrap not disabled while drawing"
grep -q $'\x1b\[?7h' "$F/anim" || fail "line wrap not restored"

timeout 10 env TORUS_FETCH_FORCE=1 TORUS_FETCH_FRAMES=3 COLUMNS=120 "$T" --forever > /dev/null < /dev/null || fail "--forever without a keyboard must still end"
TORUS_FETCH_FORCE=1 COLUMNS=60 "$T" > "$F/narrow" < /dev/null
assert_eq plain-fastfetch "$(cat "$F/narrow")" "narrow terminal means plain fastfetch"
true
