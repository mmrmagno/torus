#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$REPO"
have=$(grep -rnE '^\s*component [A-Z][A-Za-z0-9]*\s*:' --include='*.qml' home | sed -E 's/:[0-9]+:\s*component ([A-Za-z0-9]+).*/ \1/' | sort -u)
new=$(comm -13 tests/fixtures/inline-components.txt <(printf '%s\n' "$have"))
[[ -z $new ]] || fail "new inline QML components (use a component file): $(tr '\n' ' ' <<<"$new")"
echo "components: ok"
