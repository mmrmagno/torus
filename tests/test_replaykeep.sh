#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
cleanup() {
  /usr/bin/pkill -f "^python3 .*$F/sh/torus-play replay-keep" 2> /dev/null || true
  /usr/bin/pkill -f "^sleep 31[0-9]$" 2> /dev/null || true
  rm -rf "$F"
}
trap cleanup EXIT
mkdir -p "$F/bin" "$F/sh" "$F/state/torus"
export PATH=$F/bin:$PATH HOME=$F XDG_STATE_HOME=$F/state XDG_CACHE_HOME=$F/cache XDG_CONFIG_HOME=$F/config XDG_VIDEOS_DIR=$F/Videos LOG=$F/calls
stub() { printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n%s\n' "$1" "$2" > "$F/bin/$1"; chmod +x "$F/bin/$1"; }
stub torus-games 'printf "730\tCounter-Strike 2\t0\t0\t\n"'
stub hyprctl '[[ $1 == clients ]] && { [[ -e '"$F"'/closed ]] && echo "[]" || echo "[{\"class\":\"cs2\",\"pid\":4242,\"monitor\":0}]"; }; [[ $1 == monitors ]] && echo "[{\"id\":0,\"name\":\"DP-1\"}]"; exit 0'
stub torus-mangohud 'echo off'
stub qs 'exit 0'
stub pkill '[[ $1 == -INT ]] && rm -f '"$F"'/plain; exit 0'
stub powerprofilesctl 'exit 0'
stub journalctl 'exit 0'
stub pgrep '[[ -e '"$F"'/plain ]] && { echo "777 gpu-screen-recorder -w portal -f 60 -a default_output -c mp4 -r 60 -o /x/Videos"; exit 0; }; exit 1'
n=$F/gsr-count
printf '#!/usr/bin/env bash\necho "gpu-screen-recorder $*" >> "$LOG"\necho x >> %s\nc=$(wc -l < %s)\n[[ $c -eq 1 ]] && exec sleep 1\nexec sleep 31$c\n' "$n" "$n" > "$F/bin/gpu-screen-recorder"; chmod +x "$F/bin/gpu-screen-recorder"
cp "$REPO/home/.local/bin/torus-play" "$F/sh/"
P=$F/sh/torus-play
mkdir -p "$F/proc/4242"; printf 'SteamAppId=730\0' > "$F/proc/4242/environ"
export TORUS_PROC=$F/proc

touch "$F/plain"
"$P" start cs2
grep -q 'pkill -INT -f gpu-screen-recorder' "$LOG" || fail "a plain replay buffer left from the save key is stopped when a game starts: $(cat "$LOG")"
rm -f "$F/plain"
grep -q -- '^gpu-screen-recorder -w DP-1 .* -sc .*torus-play-saved' "$LOG" || fail "the game gets its own buffer that files clips under Clips: $(cat "$LOG")"

for _ in $(seq 40); do [[ $(wc -l < "$n") -ge 2 ]] && break; sleep 0.1; done
assert_eq 2 "$(wc -l < "$n")" "a game buffer that dies during the game is started again"
"$P" status | grep -q '"replay": true' || fail "the session still says the buffer runs"

: > "$LOG"
"$P" end
[[ -s $F/state/torus/play-session.json ]] || fail "leaving fullscreen (game window still open) ends the session and its buffer"
grep -q 'pkill -INT -f gpu-screen-recorder' "$LOG" && fail "leaving fullscreen stopped the replay buffer"

touch "$F/closed"
"$P" end
[[ -e $F/state/torus/play-session.json ]] && fail "the game closed: the session ends"
grep -q 'pkill -INT -f gpu-screen-recorder' "$LOG" || fail "the game closed: its buffer stops"
sleep 1.5
/usr/bin/pgrep -f "^python3 .*$F/sh/torus-play replay-keep" > /dev/null && fail "the buffer keeper stops with the session"
assert_eq 2 "$(wc -l < "$n")" "no buffer is started after the game closed"
echo "replaykeep: ok"
