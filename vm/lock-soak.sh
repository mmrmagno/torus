#!/usr/bin/env bash
# usage: lock-soak.sh [CYCLES]   (SEED=n to replay a run)
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
V=${TORUS_VM_DIR:-$HOME/vms/torus}
N=${1:-200}
SEED=${SEED:-$((RANDOM * 32768 + RANDOM))}
RANDOM=$SEED
name=""
for f in "$V"/*.pid; do [[ -e $f ]] && kill -0 "$(cat "$f")" 2> /dev/null && { name=$(basename "$f" .pid); break; }; done
[[ -n $name ]] || { echo "no VM running" >&2; exit 2; }
qmp=$V/$name.qmp
stamp=$(date +%Y%m%d-%H%M%S)
out=$V/shots/soak-$stamp
mkdir -p "$out"
log=$out/soak.log
env='export LANG=C.UTF-8 XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1) PATH=$HOME/.local/bin:$PATH;'
vm() { "$here/torus-vm" ssh "$env $1"; }
keys() { python3 "$here/qmp-keys.py" "$qmp" "$1"; }
say() { echo "$*" | tee -a "$log"; }
rnd() { local x=$((RANDOM % ($2 - $1 + 1) + $1)); printf "%d.%02d" $((x / 100)) $((x % 100)); }

fails=0 rescues=0 frames=0 wrong=0
fail() {
  fails=$((fails + 1))
  say "  FAIL cycle $c: $*"
  vm 'for m in $(hyprctl monitors -j | jq -r ".[].name"); do grim -o $m /tmp/soak-$m.png 2> /dev/null; done' > /dev/null 2>&1
  for m in $(vm 'hyprctl monitors -j | jq -r ".[].name"'); do
    "$here/torus-vm" scp-from "/tmp/soak-$m.png" "$out/fail-$c-$m-$fails.png" > /dev/null 2>&1
  done
}

state() {
  vm 's=$(timeout 3 qs -c torus ipc call torus isLocked 2> /dev/null | tail -n 1); pgrep -x hyprlock > /dev/null && s="$s+hyprlock"; echo "${s:-none}"'
}
wait_state() {
  local want=$1 tries=${2:-60} s=""
  for _ in $(seq "$tries"); do
    s=$(state)
    case $want in
      locked) [[ $s == true* || $s == *hyprlock ]] && return 0 ;;
      unlocked) [[ $s == false ]] && return 0 ;;
    esac
    sleep 0.25
  done
  echo "$s"
  return 1
}

declare -A base
check_frames() {
  local why=$1 tries=${2:-1} line m v ok bad
  for _ in $(seq "$tries"); do
    bad=""
    while read -r line; do
      [[ -n $line ]] || continue
      m=${line%%:*} v=${line#*:}
      frames=$((frames + 1))
      [[ -n ${base[$m]:-} ]] || base[$m]=$v
      ok=$(awk -v a="${base[$m]}" -v b="$v" 'BEGIN { print (b >= a * 0.6 && b >= 0.02) ? 1 : 0 }')
      ((ok)) || bad+="$m=$v(base ${base[$m]}) "
    done < <(vm 'for m in $(hyprctl monitors -j | jq -r ".[].name"); do grim -o $m /tmp/soak-$m.png 2> /dev/null && printf "%s:%s\n" $m $(magick /tmp/soak-$m.png -resize 25% -colorspace Gray -format "%[fx:standard_deviation]" info:); done')
    [[ -z $bad ]] && return 0
    sleep 1
  done
  fail "$why: low contrast $bad"
}

type_wrong() {
  keys "$(python3 "$here/qmp-text.py" - "wrong$RANDOM") ret+ 20 ret- 20"
}
type_pw() {
  keys "$(python3 "$here/qmp-text.py" "$V/password") ret+ 20 ret- 20"
}

kill_at=$((N / 3 + RANDOM % 10))
mon_at=$((2 * N / 3 + RANDOM % 10))
say "lock soak: $N cycles, seed $SEED, shell kill at $kill_at, monitor replug at $mon_at, frames in $out"
vm 'qs -c torus ipc call torus isLocked > /dev/null 2>&1' || { echo "shell not reachable" >&2; exit 2; }
[[ $(state) == false ]] || { echo "VM must start unlocked" >&2; exit 2; }
monitors=$(vm 'hyprctl monitors -j | jq -r ".[].name" | sort | tr "\n" " "')

for c in $(seq "$N"); do
  if ((RANDOM % 2)); then
    keys "meta_l+ 20 l+ 20 l- 20 meta_l- 20"
    how=keys
  else
    vm 'hyprctl eval "hl.exec_cmd(\"torus-lock\")" > /dev/null'
    how=exec
  fi
  if ! s=$(wait_state locked); then
    fail "lock by $how never became secure [$s]"
    continue
  fi
  sleep "$(rnd 40 150)"
  check_frames "locked" 2

  if ((c == kill_at)); then
    say "  cycle $c: killing the shell while locked"
    vm 'systemctl --user kill -s KILL torus-shell' > /dev/null
    sleep 2
    s=$(wait_state locked 120) || fail "after shell kill: no locker came back [$s]"
    [[ $(state) == *hyprlock ]] && { rescues=$((rescues + 1)); say "  cycle $c: hyprlock took over"; }
    check_frames "after shell kill" 15
  fi

  if ((c == mon_at)); then
    say "  cycle $c: unplugging SIDE while locked"
    vm 'hyprctl output remove SIDE' > /dev/null
    sleep 2
    check_frames "one monitor" 5
    vm 'hyprctl output create headless SIDE > /dev/null; hyprctl eval "hl.monitor({ output = \"SIDE\", mode = \"1920x1080\", position = \"1920x0\", scale = 1, transform = 3 })" > /dev/null'
    sleep 2
    [[ $(vm 'hyprctl monitors -j | jq -r ".[].name" | sort | tr "\n" " "') == "$monitors" ]] || fail "SIDE did not come back"
    check_frames "after replug" 10
  fi

  for _ in $(seq $((RANDOM % 3))); do
    type_wrong
    wrong=$((wrong + 1))
    sleep "$(rnd 0 300)"
    [[ $(state) == false ]] && fail "wrong password unlocked"
    check_frames "after wrong password" 1
  done

  unlocked=0
  for attempt in 1 2 3; do
    sleep "$(rnd 20 80)"
    type_pw
    if wait_state unlocked 40 > /dev/null; then
      unlocked=1
      break
    fi
    say "  cycle $c: unlock attempt $attempt did not take [$(state)]"
  done
  if ((!unlocked)); then
    fail "password never unlocked [$(state)]"
    vm 'pkill -USR1 -x hyprlock; qs -c torus ipc call torus isLocked' > /dev/null 2>&1
    wait_state unlocked 40 > /dev/null || { say "cannot recover, stopping"; break; }
  fi
  [[ -z $(vm 'ls /run/user/1000/torus-lock/ 2> /dev/null') ]] || fail "lock files left after unlock"
  ((c % 10 == 0)) && say "cycle $c/$N: $fails failures, $frames frames checked, $wrong wrong passwords, $rescues hyprlock takeovers"
  sleep "$(rnd 30 150)"
done

for m in "${!base[@]}"; do say "baseline contrast $m: ${base[$m]} (frames fail below 60% of it)"; done
say "lock soak done: $N cycles, $frames frames, $wrong wrong passwords, $rescues hyprlock takeovers, $fails failures (seed $SEED)"
((fails == 0))
