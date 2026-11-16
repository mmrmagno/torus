#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/run"
export PATH=$F/bin:$PATH XDG_RUNTIME_DIR=$F/run STUB_LOG=$F/calls STUB_XML=$F/xml
for c in nmcli notify-send wl-copy qs slurp grim xdg-open torus-launch; do
  printf '#!/usr/bin/env bash\necho "%s $*" >> "$STUB_LOG"\n[[ %s == nmcli && -n ${STUB_NMCLI_FAIL:-} ]] && exit 1\n[[ %s == wl-copy ]] && cat >> "$STUB_LOG.clip"\nexit 0\n' "$c" "$c" "$c" > "$F/bin/$c"
done
cat > "$F/bin/zbarimg" <<'S'
#!/usr/bin/env bash
echo "zbarimg $*" >> "$STUB_LOG"
[[ " $* " == *" --raw "* ]] && { [[ -n ${STUB_RAW:-} ]] && printf '%s' "$STUB_RAW"; exit 0; }
[[ -s $STUB_XML ]] || { printf "<barcodes>\n</barcodes>\n"; exit 4; }
cat "$STUB_XML"
S
cat > "$F/bin/tesseract" <<'S'
#!/usr/bin/env bash
printf '%s' "${STUB_TEXT:-}"
S
cat > "$F/bin/magick" <<'S'
#!/usr/bin/env bash
cp "$1" "${@: -1}"
S
chmod +x "$F/bin/"*
Q=$REPO/home/.local/bin/torus-qrscan
O=$REPO/home/.local/bin/torus-ocr
: > "$F/pic.png"

sym() { printf "<symbol type='QR-Code'><data><![CDATA[%s]]></data></symbol>\n" "$1"; }
sym64() { printf "<symbol type='QR-Code'><data format='base64' length='9'><![CDATA[\n%s\n]]></data></symbol>\n" "$(printf '%s' "$1" | base64 -w0)"; }
xml() { { echo "<barcodes><source><index num='0'>"; "$@"; echo "</index></source></barcodes>"; } > "$STUB_XML"; }
kinds() { "$Q" "$F/pic.png" | jq -r 'map(.kind + "=" + .text) | join("|")'; }

xml sym "https://example.com/a?b=1"
assert_eq "link=https://example.com/a?b=1" "$(kinds)" "an https link gets Open"
xml sym "  HTTP://Example.com  "
assert_eq "link=HTTP://Example.com" "$(kinds)" "outer whitespace trimmed, scheme case ignored"
for bad in "javascript:alert(1)" "file:///etc/passwd" "ftp://host/x" "https://a b" "data:text/html,hi"; do
  xml sym "$bad"
  assert_eq "text=$bad" "$(kinds)" "no Open for [$bad]"
done
xml sym 'ok</data><data><![CDATA[https://evil.example'
assert_eq 'text=ok</data><data><![CDATA[https://evil.example' "$(kinds)" "a payload that looks like XML stays one text row, never a link"
xml sym 'WIFI:T:WPA;S:M羹ller;P:gr羹ezi;;'
r=$(STUB_RAW='WIFI:T:WPA;S:Müller;P:grüezi;;' "$Q" "$F/pic.png")
assert_eq 'Müller|grüezi' "$(jq -r '.[0] | .ssid + "|" + .password' <<<"$r")" "one code: the exact bytes win over zbar's encoding guess"
printf '%s' "$r" | iconv -f utf-8 -t utf-8 > /dev/null || fail "output is valid UTF-8"
r=$(STUB_RAW=$(printf 'caf\xe9') "$Q" "$F/pic.png")
assert_eq "café" "$(jq -r '.[0].text' <<<"$r")" "Latin-1 bytes are read as such"
xml sym64 $'line1\nx]]>y "q" & <b>'
assert_eq $'text=line1\nx]]>y "q" & <b>' "$(kinds)" "base64 payload decoded, markup kept as text"

xml sym 'WIFI:T:WPA;S:Home\;Net;P:pa\:ss\\w\,rd";;'
r=$("$Q" "$F/pic.png")
assert_eq 'wifi|Home;Net|pa:ss\w,rd"|true|false' "$(jq -r '.[0] | [.kind, .ssid, .password, .secure, .hidden] | map(tostring) | join("|")' <<<"$r")" "wifi escaping"
xml sym 'WIFI:S:Cafe;T:nopass;H:true;;'
assert_eq 'Cafe|false|true' "$("$Q" "$F/pic.png" | jq -r '.[0] | [.ssid, .secure, .hidden] | map(tostring) | join("|")')" "open hidden network"
xml sym 'WIFI:T:WPA;P:nossid;;'
assert_eq "text=WIFI:T:WPA;P:nossid;;" "$(kinds)" "wifi without SSID is plain text"
xml eval 'sym https://one.example; sym "plain words"'
assert_eq "link=https://one.example|text=plain words" "$(kinds)" "several codes are all listed"

: > "$STUB_XML"
assert_eq "[]" "$("$Q" "$F/pic.png")" "no code: empty list, once"
mkdir -p "$F/bare"
for c in bash env perl jq cat dirname readlink; do ln -sf "$(command -v "$c")" "$F/bare/$c"; done
assert_eq "[]" "$(PATH=$F/bare "$Q" "$F/pic.png")" "zbar missing"

xml eval 'sym "https://x.example"; sym "WIFI:T:WPA;S:Home;P:secret pw;;"; sym "WIFI:S:Open;;"; sym "WIFI:T:WPA;S:Hid;P:p;H:true;;"'
"$Q" "$F/pic.png" > "$F/run/torus-qr-found.json"
: > "$STUB_LOG"
assert_eq "fail" "$("$Q" join 0 x.example || true)" "join refuses a link"
assert_eq "fail" "$("$Q" join 1 Other || true)" "join refuses when the SSID does not match the row"
assert_eq "fail" "$("$Q" join '1;rm' Home || true)" "join needs a number"
[[ ! -s $STUB_LOG ]] || fail "nmcli ran for a refused join: $(cat "$STUB_LOG")"
assert_eq "ok" "$("$Q" join 1 Home)" "join a WPA network"
assert_eq "nmcli device wifi connect Home password secret pw" "$(tail -n 1 "$STUB_LOG")" "nmcli gets SSID and password"
"$Q" join 2 Open > /dev/null
assert_eq "nmcli device wifi connect Open" "$(tail -n 1 "$STUB_LOG")" "open network: no password"
"$Q" join 3 Hid > /dev/null
assert_eq "nmcli device wifi connect Hid password p hidden yes" "$(tail -n 1 "$STUB_LOG")" "hidden network"
assert_eq "fail" "$(STUB_NMCLI_FAIL=1 "$Q" join 1 Home || true)" "nmcli failure reported"

rm -f "$F/run/torus-qr-found.json" "$STUB_LOG" "$STUB_LOG.clip"
xml sym "https://qr.example"
STUB_TEXT="" "$O" "$F/pic.png" || fail "a code without text is a success"
assert_eq "link" "$(jq -r '.[0].kind' "$F/run/torus-qr-found.json")" "ocr writes the codes it found"
grep -q "qs -c torus ipc call torus ocrShow" "$STUB_LOG" || fail "panel opens for a code without text"
grep -q "notify-send" "$STUB_LOG" && fail "no 'No text found' when a code was found"
[[ ! -e $STUB_LOG.clip ]] || fail "nothing copied when there is no text"
assert_eq "" "$(cat "$F/run/torus-ocr.txt")" "the old text is cleared"

: > "$STUB_XML"; : > "$STUB_LOG"
STUB_TEXT="" "$O" "$F/pic.png" && fail "no text and no code still fails"
grep -q "notify-send -a torus No text found" "$STUB_LOG" || fail "no text and no code: notification as before"
assert_eq "[]" "$(cat "$F/run/torus-qr-found.json")" "an old code is forgotten"

: > "$STUB_LOG"
STUB_TEXT="hello there" "$O" "$F/pic.png"
assert_eq "hello there" "$(cat "$STUB_LOG.clip")" "text still copied as before"
grep -q "ocrShow" "$STUB_LOG" || fail "panel opens for text"
assert_eq "600" "$(stat -c %a "$F/run/torus-qr-found.json")" "codes file is private"
echo "qrscan: ok"
