#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/data" "$F/docs"
touch "$F/docs/old.txt" "$F/docs/new report.pdf"
cat > "$F/data/recently-used.xbel" <<X
<?xml version="1.0" encoding="UTF-8"?>
<xbel version="1.0">
  <bookmark href="file://$F/docs/old.txt" added="2026-11-01T10:00:00Z" modified="2026-11-01T10:00:00Z" visited="2026-11-01T10:00:00Z"/>
  <bookmark href="file://$F/docs/new%20report.pdf" added="2026-11-08T10:00:00Z" modified="2026-11-08T10:00:00Z" visited="2026-11-08T10:00:00Z"/>
  <bookmark href="file://$F/docs/gone.txt" added="2026-11-09T10:00:00Z" modified="2026-11-09T10:00:00Z" visited="2026-11-09T10:00:00Z"/>
  <bookmark href="https://example.org/" added="2026-11-09T10:00:00Z" modified="2026-11-09T10:00:00Z" visited="2026-11-09T10:00:00Z"/>
</xbel>
X
out=$(XDG_DATA_HOME=$F/data "$REPO/home/.local/bin/torus-recent")
assert_eq "$(printf '2026-11-08\t%s\n2026-11-01\t%s' "$F/docs/new report.pdf" "$F/docs/old.txt")" "$out" "newest first, spaces decoded, missing and non-file entries dropped"
assert_eq "" "$(XDG_DATA_HOME=$F/none "$REPO/home/.local/bin/torus-recent")" "no history file is fine"
true
