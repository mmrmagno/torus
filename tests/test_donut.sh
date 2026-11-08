#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
deno run --quiet --allow-read "$REPO/tests/donut/check.ts" > "$F/check" 2>&1 || { cat "$F/check" >&2; fail "donut check"; }

deno run --quiet --allow-read --allow-write "$REPO/donut/render-logo.ts" "$F/ff" > /dev/null
assert_file "$F/ff/logo.txt"
assert_eq 20 "$(wc -l < "$F/ff/logo.txt")" "logo lines"
perl -pe 's/\$(\$|[1-9])/$1 eq "\$" ? "\$" : ""/ge' "$F/ff/logo.txt" > "$F/visible"
deno eval --quiet "import { grid, CHARS, W, H } from '$REPO/donut/donut.mjs'; const g = grid(1, 1); for (let r = 0; r < H; r++) { let l = ''; for (let c = 0; c < W; c++) { const v = g[r * W + c]; l += v < 0 ? ' ' : CHARS[v]; } console.log(l.trimEnd()); }" > "$F/expected"
diff "$F/expected" "$F/visible" > /dev/null || fail "logo text differs from the donut after fastfetch decoding"
grep -q '\$[1-9]' "$F/ff/logo.txt" || fail "logo has no color slots"
jq -e '.logo.color["1"]' "$F/ff/config.jsonc" > /dev/null || fail "fastfetch config lacks color slots"
cmp -s "$F/ff/config.jsonc" "$REPO/home/.config/fastfetch/config.jsonc" || fail "committed fastfetch config differs from render-logo.ts output"
jq -r ".modules[].key // empty" "$F/ff/config.jsonc" | grep -E "^ |^[a-z]" && fail "fastfetch key without an icon"
jq -r '.modules[] | select(.type == "command") | .key' "$F/ff/config.jsonc" | grep -q " age$" || fail "fastfetch has no system age"

deno run --quiet --allow-read --allow-write --allow-run "$REPO/donut/render-frames.ts" "$F/frames" 3 400 > /dev/null
assert_eq 3 "$(ls "$F/frames"/frame-*.png | wc -l)" "frame count"
assert_eq 400 "$(magick identify -format %w "$F/frames/frame-0000.png")" "frame width"
grep -q 'font_features="liga 0, calt 0"' "$REPO/donut/render-frames.ts" || fail "frames must disable ligatures"

cat > "$F/living.ts" <<'T'
import { living, ramp } from "REPO/home/.config/quickshell/torus/background/donut.mjs";
const p = JSON.parse(Deno.readTextFileSync("REPO/theme/mocha.json"));
const r = (o: Record<string, string>) => ramp(o).join(",");
const off = r(living(p, 8, "", false));
const morning = r(living(p, 8, "", true));
const night = r(living(p, 22, "", true));
const red = r(living(p, 22, "#ff0000", true));
console.log([off === r(p), morning !== night, red !== night, living(p, 22, "#ff0000", true).base === p.base].join(" "));
T
sed -i "s#REPO#$REPO#g" "$F/living.ts"
assert_eq "true true true true" "$(deno run --quiet --allow-read "$F/living.ts")" "living donut: off is plain, follows hour and art, keeps base"
true
grep -nE "\\{ *\\.\\.\\." "$REPO/donut/donut.mjs" && fail "donut.mjs uses object spread, which the QML JS engine rejects"
true
