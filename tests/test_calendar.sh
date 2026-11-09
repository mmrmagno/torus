#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

T=$REPO/home/.local/bin/torus-calendar
out=$(TZ=Europe/Zurich "$T" parse --from 2026-11-09 --days 7 < "$REPO/tests/fixtures/calendar.ics")
expected=$(printf '%s\n' \
  "2026-11-09T16:00	2026-11-09T17:00	0	Standup, team (moved)	" \
  "2026-11-10T10:00	2026-11-10T10:30	0	Dentist	Bahnhofstrasse 1" \
  "2026-11-12T00:00	2026-11-13T00:00	1	Holiday	")
assert_eq "$expected" "$out" "events in the window: repeats expanded, skipped date dropped, all-day kept, old dropped"
true
