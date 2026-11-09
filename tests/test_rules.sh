#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin"
export HOME=$F/home STUB_LOG=$F/calls XDG_STATE_HOME=$F/home/.local/state
printf '#!/usr/bin/env bash\necho "hyprctl $*" >> "$STUB_LOG"\n' > "$F/bin/hyprctl"
chmod +x "$F/bin"/*
export PATH=$F/bin:$PATH
T=$REPO/home/.local/bin/torus-rules
L=$HOME/.config/hypr/rules.local.lua

"$T" add cs2 cursor
"$T" add org.gnome.Calculator float
"$T" add org.gnome.Calculator workspace 4
"$T" add org.gnome.Calculator workspace 5
assert_eq "$(printf 'cs2\tcursor\t\norg.gnome.Calculator\tfloat\t\norg.gnome.Calculator\tworkspace\t5')" "$("$T" list)" "list: one rule per kind, last wins"
assert_contains "$L" 'match = { class = "^(cs2)$", fullscreen = true }, confine_pointer = true'
assert_contains "$L" 'match = { class = "^(org\\.gnome\\.Calculator)$" }, float = true'
assert_contains "$L" 'workspace = "5"'
grep -q 'workspace = "4"' "$L" && fail "old workspace rule kept"
grep -q '^hyprctl reload' "$STUB_LOG" || fail "rules applied"

"$T" remove org.gnome.Calculator
assert_eq "$(printf 'cs2\tcursor\t')" "$("$T" list)" "remove drops every rule of that app"
grep -q Calculator "$L" && fail "removed app still in the lua file"

rc=0; "$T" add 'bad"class' float > /dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "refuses classes that could break the lua file"
rc=0; "$T" add kitty workspace abc > /dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "workspace must be a number"
for i in $(seq 12); do "$T" add "app$i" float & done; wait
assert_eq 12 "$(grep -c '^app[0-9]*	float' "$XDG_STATE_HOME/torus/rules.tsv")" "parallel adds all land"
assert_eq 12 "$(grep -c 'class = "\^(app[0-9]*)\$"' "$HOME/.config/hypr/rules.local.lua")" "lua file matches the tsv after parallel adds"
true
