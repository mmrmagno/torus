#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/state/torus"
export PATH=$F/bin:$PATH HOME=$F XDG_STATE_HOME=$F/state XDG_CACHE_HOME=$F/cache XDG_CONFIG_HOME=$F/config XDG_VIDEOS_DIR=$F/Videos LOG=$F/calls
stub() { printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n%s\n' "$1" "$2" > "$F/bin/$1"; chmod +x "$F/bin/$1"; }
stub torus-games 'printf "730\tCounter-Strike 2\t0\t0\t\n"'
stub hyprctl '[[ $1 == clients ]] && echo "[{\"class\":\"steam_app_730\",\"monitor\":1}]"; [[ $1 == monitors ]] && echo "[{\"id\":0,\"name\":\"DP-2\"},{\"id\":1,\"name\":\"DP-1\"}]"; exit 0'
stub torus-mangohud 'echo off'
stub qs 'exit 0'
stub pgrep 'exit 1'
stub pkill 'exit 0'
stub powerprofilesctl 'exit 0'
stub gpu-screen-recorder 'exit 0'
stub setsid 'echo "setsid $*" >> "$LOG"'
P=$REPO/home/.local/bin/torus-play

assert_eq '{"overlay": "keep", "power": "performance", "replay": "on", "replay_secs": 60, "hold": "on", "gamescope": "off"}' "$("$P" settings 730)" "defaults"
"$P" set 730 replay_secs 120
"$P" set 730 hold off
assert_fails "$P" set 730 replay_secs 45
assert_eq '120:off' "$("$P" settings 730 | jq -r '"\(.replay_secs):\(.hold)"')" "per-game settings stored by app id"
[[ -f $F/config/torus/games.json ]] || fail "games.json written"

mkdir -p "$F/proc/4242"; printf 'HOME=/x\0SteamAppId=730\0' > "$F/proc/4242/environ"
stub hyprctl '[[ $1 == clients ]] && echo "[{\"class\":\"cs2\",\"pid\":4242,\"monitor\":1}]"; [[ $1 == monitors ]] && echo "[{\"id\":0,\"name\":\"DP-2\"},{\"id\":1,\"name\":\"DP-1\"}]"; exit 0'
TORUS_PROC=$F/proc "$P" start cs2
assert_eq "730:Counter-Strike 2" "$("$P" status | jq -r '"\(.appid):\(.name)"')" "a native game's app id comes from its process (cs2 has no steam_app_ class)"
grep -q -- "gpu-screen-recorder -w DP-1 .* -r 120 " "$LOG" || fail "its own settings apply: $(cat "$LOG")"
rm "$F/state/torus/play-session.json"; : > "$LOG"
stub hyprctl '[[ $1 == clients ]] && echo "[{\"class\":\"steam_app_730\",\"monitor\":1}]"; [[ $1 == monitors ]] && echo "[{\"id\":0,\"name\":\"DP-2\"},{\"id\":1,\"name\":\"DP-1\"}]"; exit 0'
"$P" start steam_app_730
grep -q -- "gpu-screen-recorder -w DP-1 -f 60 -a default_output -c mp4 -r 120 -sc .*torus-play-saved -o $F/Videos" "$LOG" || fail "replay buffer on the game's monitor: $(cat "$LOG")"
assert_eq "Counter-Strike 2:true:off" "$("$P" status | jq -r '"\(.name):\(.replay):\(.hold)"')" "session recorded"
[[ -e $F/state/torus/mangohud-log ]] && fail "no MangoHud logging (its log dot sits on top of the game)"

assert_eq monitor "$("$P" status | jq -r .capture)" "no portal picker configured: whole monitor"
rm "$F/state/torus/play-session.json"; : > "$LOG"
mkdir -p "$F/config/hypr"; echo 'screencopy { custom_picker_binary = torus-share-picker }' > "$F/config/hypr/xdph.conf"
printf '#!/bin/sh\nexit 0\n' > "$F/bin/torus-share-picker"; chmod +x "$F/bin/torus-share-picker"
printf '#!/usr/bin/env bash\necho "gpu-screen-recorder $*" >> "$LOG"\nexec sleep 30\n' > "$F/bin/gpu-screen-recorder"; chmod +x "$F/bin/gpu-screen-recorder"
"$P" set 730 overlay on
stub torus-mangohud 'echo off'
"$P" start steam_app_730 &
for _ in $(seq 20); do [[ -s $F/state/torus/play-session.json ]] && break; sleep 0.1; done
"$P" start steam_app_730
mkdir -p "$F/Videos"; ffmpeg -v error -f lavfi -i color=c=blue:s=64x48:d=1 -c:v libx264 "$F/Videos/early.mp4"
"$P" saved "$F/Videos/early.mp4" > /dev/null
wait
assert_eq "1:off" "$("$P" status | jq -r '"\(.clips):\(.overlay_before)"')" "a second start while the recorder starts changes nothing, an early clip and the overlay state survive"
"$P" set 730 overlay keep
rm -rf "$F/Videos/Clips"
grep -q -- "^gpu-screen-recorder -w portal -restore-portal-session no -f 60 .* -r 120 " "$LOG" || fail "window capture through the portal: $(cat "$LOG")"
assert_eq "steam_app_730" "$(cat "$F/state/torus/share-target")" "the picker is told which window"
assert_eq window "$("$P" status | jq -r .capture)" "session says window"
pkill -f "^sleep 30$" || true
rm "$F/state/torus/play-session.json" "$F/state/torus/share-target"; : > "$LOG"
printf '#!/usr/bin/env bash\necho "gpu-screen-recorder $*" >> "$LOG"\nexit 1\n' > "$F/bin/gpu-screen-recorder"; chmod +x "$F/bin/gpu-screen-recorder"
"$P" start steam_app_730
grep -q -- "setsid -f gpu-screen-recorder -w DP-1 " "$LOG" || fail "falls back to the monitor when the portal fails: $(cat "$LOG")"
[[ -e $F/state/torus/share-target ]] && fail "a failed portal start leaves no stale target"
mkdir -p "$F/Videos"
ffmpeg -v error -f lavfi -i color=c=red:s=64x48:d=2 -c:v libx264 "$F/Videos/Replay_x.mp4"
dest=$("$P" saved "$F/Videos/Replay_x.mp4")
[[ $dest == "$F/Videos/Clips/counter-strike-2/counter-strike-2-"*.mp4 && -f $dest ]] || fail "clip filed by game: $dest"
grep -q "islandFlash notification Clip saved · Counter-Strike 2 · 120 s" "$LOG" || fail "island says the clip is saved"
out=$("$P" clips 730)
[[ $(cut -f1 <<< "$out") == "$dest" && -s $(cut -f3 <<< "$out") ]] || fail "clips listed with a thumbnail: $out"

log=$F/cache/torus/mangohud-logs/cs2_2026.csv
mkdir -p "$(dirname "$log")"
{ echo "os,cpu,gpu"; echo "Arch,x,y"; echo "fps,frametime,cpu_load,gpu_load,cpu_temp,gpu_temp,elapsed"
  for i in $(seq 99); do echo "200,5.0,10,90,60,70,$i"; done; echo "50,20.0,10,90,60,78,100"; } > "$log"
jq '.start -= 6300' "$F/state/torus/play-session.json" > "$F/s.json" && mv "$F/s.json" "$F/state/torus/play-session.json"
touch "$log"
"$P" end
r=$("$P" recap)
assert_eq "105:198:50:78:1" "$(jq -r '"\(.minutes):\(.fps_avg):\(.fps_low1):\(.gpu_temp_max):\(.clips)"' <<< "$r")" "recap numbers"
assert_eq "Counter-Strike 2: played 1 h 45 · average 198 FPS · 1 % low 50 · GPU max 78 °C · 1 clip saved" "$(jq -r .text <<< "$r")" "recap text"
grep -q "pkill -INT -f gpu-screen-recorder .*-r " "$LOG" || fail "the buffer stops with the game"
[[ ! -e $F/state/torus/play-session.json && ! -e $F/state/torus/mangohud-log ]] || fail "session cleaned up"
echo "play: ok"
