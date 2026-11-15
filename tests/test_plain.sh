#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

P=$REPO/home/.local/bin/torus-plain
plain() { printf '%b' "$1" | "$P"; }

assert_eq "hello" "$(plain '  \n\n  hello  \n\n ')" "outer whitespace and blank lines trimmed"
assert_eq $'a\nb' "$(plain 'a   \nb\t\t')" "trailing spaces and tabs per line"
assert_eq "it's \"quoted\" 'single' \"low\"" "$(plain 'it\u2019s \u201cquoted\u201d \u2018single\u2019 \u201elow\u201f')" "curly quotes straight"
assert_eq "5 km and 3 h" "$(plain '5\u00a0km and 3\u202fh')" "non-breaking spaces become spaces"
assert_eq "zerowidth" "$(plain '\ufeffzero\u200bwi\u2060dth\u200c')" "zero-width characters removed"
assert_eq "ab" "$(plain 'a\u200db')" "a joiner between letters is removed"
assert_eq "$(printf '\U0001F468\u200d\U0001F469')" "$(plain '\U0001F468\u200d\U0001F469')" "a joiner inside an emoji stays"
assert_eq $'one\ntwo\nthree' "$(plain 'one\r\ntwo\rthree\r\n')" "Windows and old Mac line ends"
code=$'def f(x):\n    if x:\n\t\treturn "a  b"\n    return 1'
assert_eq "$code" "$(printf '%s\n\n' "$code" | "$P")" "code indentation and inner spaces untouched"
assert_eq $'    indented\n    block' "$(plain '\n    indented\n    block  \n')" "a multi-line block keeps its first indent"
assert_eq $'first line\n    if x:\n\treturn' "$(plain '  first line\n    if x:\n\treturn')" "a first line indented unlike the rest is trimmed"
assert_eq "" "$(plain '  \n \t ')" "only whitespace becomes empty"
assert_eq "ünïcödé ✓" "$(plain 'ünïcödé ✓')" "other unicode untouched"
big=$(head -c 300000 /dev/zero | tr '\0' x)
assert_eq 300000 "$(printf '%s' "$big" | "$P" | wc -c)" "large text passes through"
echo "plain: ok"
