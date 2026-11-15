#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/run" "$F/dir/sub"
export XDG_RUNTIME_DIR=$F/run
L=$REPO/home/.local/bin/torus-look
touch "$F/dir/b.txt" "$F/dir/a.txt"
printf 'hello\nworld\n' > "$F/note.md"
printf '{"a": 1}\n' > "$F/data.json"
printf '#!/bin/sh\necho hi\n' > "$F/run.sh"
: > "$F/empty"
seq 1 100000 > "$F/big.log"
head -c 4096 /dev/urandom > "$F/blob.bin"
printf '\x89PNG\r\n\x1a\n\0\0\0\rIHDR\0\0\0\1\0\0\0\1\x08\x02\0\0\0\x90wS\xde\0\0\0\x0cIDATx\x9cc\xf8\xff\xff?\0\x05\xfe\x02\xfe\xa7\x35\x81\x84\0\0\0\0IEND\xaeB`\x82' > "$F/pic.png"

assert_eq "folder|sub/|a.txt|b.txt" "$("$L" "$F/dir" | tr '\n' '|' | sed 's/|$//')" "folder: folders first, then files"
assert_eq "text|hello|world" "$("$L" "$F/note.md" | tr '\n' '|' | sed 's/|$//')" "markdown is text"
assert_eq "text" "$("$L" "$F/data.json" | head -1)" "json is text"
assert_eq "text" "$("$L" "$F/run.sh" | head -1)" "a script is text"
assert_eq "text" "$("$L" "$F/empty")" "an empty file is empty text"
(( $("$L" "$F/big.log" | wc -l) <= 401 )) || fail "a big text file is cut to the first lines"
assert_eq "image" "$("$L" "$F/pic.png")" "png is an image"
out=$("$L" "$F/blob.bin")
[[ $(head -1 <<< "$out") == other && $(sed -n 2p <<< "$out") == "4096 "* ]] || fail "binary: size and date, got [$out]"
assert_eq "error" "$("$L" "$F/missing")" "missing file"
assert_eq "error" "$("$L" "")" "no path"
if command -v pdftoppm > /dev/null && command -v magick > /dev/null; then
  magick -size 200x100 xc:white "$F/doc.pdf" 2> /dev/null && {
    out=$("$L" "$F/doc.pdf")
    [[ $(head -1 <<< "$out") == pdf && -s $(sed -n 2p <<< "$out") ]] || fail "pdf: first page rendered, got [$out]"
  }
fi
echo "look: ok"
