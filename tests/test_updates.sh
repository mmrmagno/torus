#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin"
export STUB_LOG=$F/calls TORUS_PACMAN_LOG=$F/pacman.log XDG_CACHE_HOME=$F/cache
printf '#!/usr/bin/env bash\necho "checkupdates" >> "$STUB_LOG"\nprintf "linux 7.2.14.arch1-1 -> 7.2.15.arch1-1\\nmesa 1:26.0.1-1 -> 1:26.0.2-1\\n"\n' > "$F/bin/checkupdates"
printf '#!/usr/bin/env bash\necho "yay $*" >> "$STUB_LOG"\n[[ $1 == -Syu ]] && exit ${YAY_FAIL:-0}\nprintf "vesktop-bin 1.5.3-1 -> 1.5.4-1\\n"\n' > "$F/bin/yay"
cat > "$F/bin/curl" <<'S'
#!/usr/bin/env bash
echo "curl $*" >> "$STUB_LOG"
[[ -n ${STUB_429:-} ]] && exit 22
cat <<'X'
<?xml version="1.0"?><rss><channel><title>Arch Linux: Recent news updates</title>
<item><title>Manual intervention for foo &amp; bar</title><link>https://archlinux.org/news/foo/</link><pubDate>Fri, 06 Nov 2026 12:00:00 +0000</pubDate></item>
<item><title>Old news item</title><link>https://archlinux.org/news/old/</link><pubDate>Mon, 01 Jun 2026 10:00:00 +0000</pubDate></item>
</channel></rss>
X
S
chmod +x "$F/bin"/*
export PATH=$F/bin:$PATH
printf '[2026-10-20T10:00:00+0200] [PACMAN] starting full system upgrade\n[2026-10-20T10:01:00+0200] [ALPM] upgraded foo\n' > "$TORUS_PACMAN_LOG"
T=$REPO/home/.local/bin/torus-updates

assert_eq "$(printf 'repo\tlinux\t7.2.14.arch1-1\t7.2.15.arch1-1\nrepo\tmesa\t1:26.0.1-1\t1:26.0.2-1\naur\tvesktop-bin\t1.5.3-1\t1.5.4-1')" "$("$T" list)" "list: repo and aur with versions"
out=$("$T" news 5)
assert_eq "$(printf 'new\t2026-11-06\tManual intervention for foo & bar\thttps://archlinux.org/news/foo/\nseen\t2026-06-01\tOld news item\thttps://archlinux.org/news/old/')" "$out" "news: newer than the last full upgrade is new"
grep -q 'curl .*archlinux.org/feeds/news' "$STUB_LOG" || fail "news from the arch feed"
: > "$STUB_LOG"
assert_eq "$out" "$("$T" news 5)" "a second look within the hour uses the cache"
grep -q curl "$STUB_LOG" && fail "no fetch within the hour, archlinux.org rate-limits"
touch -d "-2 hours" "$XDG_CACHE_HOME/torus/arch-news.tsv"
: > "$STUB_LOG"
assert_eq "$out" "$(STUB_429=1 "$T" news 5)" "a failed or rate-limited fetch keeps the last news"
grep -q curl "$STUB_LOG" || fail "an old cache is refreshed"
: > "$STUB_LOG"
STUB_429=1 "$T" news 5 > /dev/null
grep -q curl "$STUB_LOG" && fail "after a failure it waits ten minutes before trying again"
rm -rf "$XDG_CACHE_HOME"
assert_eq "" "$(STUB_429=1 "$T" news 5)" "no cache and no network: nothing"
true

printf '#!/usr/bin/env bash\necho "qs $*" >> "$STUB_LOG"\n' > "$F/bin/qs"
printf '#!/usr/bin/env bash\necho "launch $*" >> "$STUB_LOG"\n' > "$F/bin/torus-launch"
printf '#!/usr/bin/env bash\necho "doctor" >> "$STUB_LOG"\nexit ${DOCTOR_FAILS:-0}\n' > "$F/bin/torus-doctor"
chmod +x "$F/bin"/*
"$T" news 5 > /dev/null
: > "$STUB_LOG"
echo n | "$T" upgrade > "$F/out" && fail "news stops the upgrade unless confirmed"
grep -q 'Manual intervention for foo & bar' "$F/out" || fail "the new news is shown"
grep -q '^yay' "$STUB_LOG" && fail "nothing ran before the news was read"
grep -q 'islandFlash notification Update stopped' "$STUB_LOG" || fail "island says it stopped"
: > "$STUB_LOG"
printf 'o\ny\n' | "$T" upgrade > /dev/null || fail "o opens, y goes on"
grep -q 'launch xdg-open https://archlinux.org/news/foo/' "$STUB_LOG" || fail "o opens the new news"
grep -q '^yay -Syu' "$STUB_LOG" || fail "then the upgrade runs: $(cat "$STUB_LOG")"
grep -q '^doctor' "$STUB_LOG" || fail "torus doctor after"
grep -q 'islandFlash notification Update done · torus doctor: all green' "$STUB_LOG" || fail "result on the island"
printf '[2026-11-12T10:00:00+0100] [PACMAN] starting full system upgrade\n' >> "$TORUS_PACMAN_LOG"
: > "$STUB_LOG"
DOCTOR_FAILS=2 "$T" upgrade < /dev/null > /dev/null && fail "doctor problems give a non-zero exit"
grep -q 'torus doctor found 2 problems' "$STUB_LOG" || fail "no news, straight to the upgrade, problems reported: $(cat "$STUB_LOG")"
: > "$STUB_LOG"
YAY_FAIL=1 "$T" upgrade < /dev/null > /dev/null && fail "a failed upgrade fails"
grep -q 'Update failed' "$STUB_LOG" || fail "and says so"
grep -q '^doctor' "$STUB_LOG" && fail "no doctor after a failed upgrade"
echo "updates: ok"
