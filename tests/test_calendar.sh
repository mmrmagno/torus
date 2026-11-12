#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

T=$REPO/home/.local/bin/torus-calendar
out=$(TZ=Europe/Zurich "$T" parse --from 2026-11-09 --days 7 < "$REPO/tests/fixtures/calendar.ics")
expected=$(printf '%s\n' \
  "2026-11-09T16:00	2026-11-09T17:00	0	Standup, team (moved)		" \
  "2026-11-10T10:00	2026-11-10T10:30	0	Dentist	Bahnhofstrasse 1	" \
  "2026-11-12T00:00	2026-11-13T00:00	1	Holiday		")
assert_eq "$expected" "$out" "events in the window: repeats expanded, skipped date dropped, all-day kept, old dropped"

out=$(TZ=Europe/Zurich "$T" parse --from 2026-10-20 --days 45 < "$REPO/tests/fixtures/calendar-rules.ics")
grep -qx $'2026-11-04T10:00\t2026-11-04T11:00\t0\tWeekly over DST\t\t' <<<"$out" || fail "weekly event keeps 10:00 after DST ends: $out"
grep -qx $'2026-11-02T10:00\t2026-11-02T10:30\t0\tUTC after DST\t\t' <<<"$out" || fail "UTC event uses winter offset after DST"
grep -qx $'2026-11-02T08:00\t2026-11-02T09:00\t0\tFirst Monday\t\t' <<<"$out" || fail "MONTHLY BYDAY=1MO on Nov 2"
grep -q $'2026-11-05T08:00\t.*First Monday' <<<"$out" && fail "MONTHLY BYDAY must not repeat on the 5th"
grep -qx $'2026-11-27T17:00\t2026-11-27T18:00\t0\tLast Friday\t\t' <<<"$out" || fail "MONTHLY BYDAY=-1FR on Nov 27"
grep -q 'Unsupported rule' <<<"$out" || fail "unsupported FREQ still shows its first instance"
grep -q 'Broken' <<<"$out" && fail "broken event dropped"
out=$(TZ=Europe/Zurich "$T" parse --from 2026-11-09 --days 3 < "$REPO/tests/fixtures/calendar-calls.ics")
grep -qx $'2026-11-10T09:00\t2026-11-10T09:30\t0\tSync\t\thttps://meet.google.com/abc-defg-hij' <<<"$out" || fail "Meet link from X-GOOGLE-CONFERENCE: $out"
grep -qx $'2026-11-10T11:00\t2026-11-10T12:00\t0\tReview\tRoom 4\thttps://us02web.zoom.us/j/123456789?pwd=x' <<<"$out" || fail "Zoom link from the description"
grep -qx $'2026-11-10T14:00\t2026-11-10T15:00\t0\tLunch\tTeams? no\t' <<<"$out" || fail "no link, no join"
true
