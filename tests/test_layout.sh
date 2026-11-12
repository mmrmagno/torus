#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/proj"
printf '#!/bin/sh\nprintf "%%s\\t%%s\\t%%s\\t%%s\\n" "%s" main 0 https://github.com/me/proj\n' "$F/proj" > "$F/bin/torus-projects"
chmod +x "$F/bin/torus-projects"
export PATH=$F/bin:$PATH TORUS_LAYOUT_DRY=1
L=$REPO/home/.local/bin/torus-layout
assert_eq "kitty --directory $F/proj nvim .
kitty --directory $F/proj
xdg-open https://github.com/me/proj" "$("$L" "$F/proj")" "default: nvim, terminal, repo page"
printf 'lazygit\nurl https://ci.example.test/x\nrm -rf /\nurl javascript:alert(1)\nterm\n' > "$F/proj/.torus-layout"
assert_eq "kitty --directory $F/proj lazygit
xdg-open https://ci.example.test/x
kitty --directory $F/proj" "$("$L" "$F/proj")" "per-project file, unknown verbs and odd URLs ignored"
echo "layout: ok"
