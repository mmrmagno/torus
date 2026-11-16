#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/state/torus"
export XDG_STATE_HOME=$F/state STUB_LOG=$F/calls
cp "$REPO/home/.local/bin/torus-see" "$F/bin/"
printf '#!/usr/bin/env bash\necho "reload $* $(cat)" >> "$STUB_LOG"\n' > "$F/bin/torus-reload"
printf '#!/usr/bin/env bash\necho "rules $*" >> "$STUB_LOG"\n' > "$F/bin/torus-rules"
chmod +x "$F/bin/"*
S=$F/bin/torus-see

for bad in "" -1 1.6 abc "1;rm" 2; do
  "$S" "$bad" 2> /dev/null && fail "accepted [$bad]"
done
[[ ! -e $STUB_LOG ]] || fail "a refused value touched something: $(cat "$STUB_LOG")"
"$S" 0.5
assert_eq "reload write $F/state/torus/see-through 0.5" "$(cat "$STUB_LOG")" "no personal rules: written through torus-reload"
: > "$STUB_LOG"
printf 'kitty\topacity\t\n' > "$F/state/torus/rules.tsv"
"$S" 1.2
assert_eq "1.2" "$(cat "$F/state/torus/see-through")" "value saved"
assert_eq "rules render" "$(cat "$STUB_LOG")" "personal rules re-rendered, one reload"

if command -v lua > /dev/null; then
  look() {
    lua -e "
      hl = { config = function(t) print(string.format('%.3f %.3f', t.decoration.active_opacity, t.decoration.inactive_opacity)) end }
      torus = { state = '$F/state/torus/', read = function(p, d) local f = io.open(p) if not f then return d end local v = f:read('*l') f:close() return v end }
      dofile('$REPO/home/.config/hypr/torus/look.lua')
      print(torus.opacity(0.80, 0.70))"
  }
  echo 1 > "$F/state/torus/see-through"
  assert_eq $'0.900 0.750\n0.800 0.700 1' "$(look)" "1 keeps today's look exactly"
  echo 0 > "$F/state/torus/see-through"
  assert_eq $'1.000 1.000\n1.000 1.000 1' "$(look)" "0 is solid everywhere"
  echo 1.5 > "$F/state/torus/see-through"
  assert_eq $'0.850 0.625\n0.700 0.550 1' "$(look)" "1.5 is glassier"
  echo junk > "$F/state/torus/see-through"
  assert_eq $'0.900 0.750\n0.800 0.700 1' "$(look)" "a broken file falls back to the default"
fi
echo "see: ok"
