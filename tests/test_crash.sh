#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin"
export XDG_CACHE_HOME=$F/cache STUB_LOG=$F/calls PATH=$F/bin:$PATH TORUS_CRASH_DELAY=0
stub() { printf '#!/usr/bin/env bash\necho "%s $*" >> "$STUB_LOG"\n%s\n' "$1" "$2" > "$F/bin/$1"; chmod +x "$F/bin/$1"; }
stub journalctl 'echo "line from $*"; [[ $* == *-o\ cat* ]] && echo "WARN qml: Foo.qml:3: TypeError: x is undefined"'
stub notify-send 'echo "${STUB_ACTION:-}"'
stub kitty 'exit 0'
stub hyprctl '[[ -z ${STUB_NO_HYPR:-} ]]'
T=$REPO/home/.local/bin/torus-crash
D=$XDG_CACHE_HOME/torus/crashes

SERVICE_RESULT=success "$T" save
[[ -d $D ]] && fail "a clean stop saves nothing"

STUB_NO_HYPR=1 SERVICE_RESULT=exit-code EXIT_STATUS=255 "$T" save
[[ -d $D ]] && fail "a shell that died with the compositor (logout, reboot) is not a crash"

SERVICE_RESULT=signal EXIT_CODE=killed EXIT_STATUS=KILL "$T" save
assert_eq 1 "$("$T" list | wc -l)" "one crash saved"
[[ $("$T" list) == "$D/"*.log ]] || fail "listed by path"
assert_contains "$D/pending" "signal"
out=$("$T" last)
grep -q 'result: signal killed KILL' <<< "$out" || fail "result recorded: $out"
grep -q 'line from --user -u torus-shell.service -n 80' <<< "$out" || fail "shell log saved"
grep -q 'line from --user -n 50' <<< "$out" || fail "session journal saved"
grep -q '^== QML warnings in this run' <<< "$out" || fail "QML warnings section"
grep -q 'TypeError: x is undefined' <<< "$out" || fail "the run's QML warning is in the log"
assert_eq 700 "$(stat -c %a "$D")" "crash logs private"

STUB_ACTION=open "$T" notify
for _ in $(seq 50); do grep -q '^kitty' "$STUB_LOG" 2> /dev/null && break; sleep 0.1; done
grep -q 'notify-send -a torus .*The shell restarted after a crash.*stopped with: signal' "$STUB_LOG" || fail "notification sent: $(cat "$STUB_LOG")"
grep -q "^kitty --title torus-crash nvim -R +/== QML warnings $D/" "$STUB_LOG" || fail "open shows the log at the QML warnings"
[[ -e $D/pending ]] && fail "notify clears pending"
: > "$STUB_LOG"
"$T" notify
sleep 0.3
grep -q notify-send "$STUB_LOG" && fail "one notification per crash"

for i in $(seq 12); do touch -d "-$i min" "$D/old$i.log"; done
SERVICE_RESULT=exit-code "$T" save
assert_eq 10 "$("$T" list | wc -l)" "keeps the newest 10"
if grep -q "$D/old12.log" <<< "$("$T" list)"; then fail "oldest dropped"; fi
