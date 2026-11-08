#!/usr/bin/env bash
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
export LANG=${LANG:-C.UTF-8}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)
export HYPRLAND_INSTANCE_SIGNATURE
QS=(qs -c torus ipc call torus)

passed=0 total=0
section() {
  local name=$1 result=$2 detail=$3
  total=$((total + 1))
  if [[ $result == ok ]]; then
    passed=$((passed + 1))
    echo "$name: ok $detail"
  else
    echo "$name: FAIL $detail"
  fi
}

bind_list() {
  hyprctl binds -j | jq -r '
    def mods: [ (if (.modmask/64|floor)%2==1 then "SUPER" else empty end), (if (.modmask/4|floor)%2==1 then "CTRL" else empty end), (if (.modmask/8|floor)%2==1 then "ALT" else empty end), (if .modmask%2==1 then "SHIFT" else empty end)] | join("+");
    .[] | ((mods) as $m | if $m=="" then .key else $m+"+"+.key end) + (if .release then " release" else "" end)' | sort -u
}

check_binds() {
  local missing errors
  missing=$(comm -23 <(sort -u "$REPO/tests/binds.expected") <(bind_list))
  errors=$(hyprctl configerrors 2>&1 | grep -v '^\s*$' || true)
  local want have
  want=$(sort -u "$REPO/tests/binds.expected" | wc -l)
  have=$((want - $(grep -c . <<<"$missing")))
  if [[ -z $missing && -z $errors ]]; then
    section binds ok "$have/$want, configerrors: none"
  else
    section binds fail "$have/$want missing: $(tr '\n' ' ' <<<"$missing") configerrors: $(tr '\n' ' ' <<<"$errors")"
  fi
}

BAR_MODULES="cpu memory cpuinfo gpuinfo idle clock workspaces taskbar media sunset network audio mic updates keyhint privacy tray wallpaper accent barpreset clipboard menu notifications power"

check_bar() {
  local out screens bad=""
  out=$("${QS[@]}" modules 2>&1)
  screens=$(hyprctl monitors -j | jq -r '.[].name' | sort)
  for s in $screens; do
    local have want
    have=$(tr ';' '\n' <<<"$out" | grep "^$s:" | cut -d: -f2 | tr ',' '\n' | sort -u)
    want=$(tr ' ' '\n' <<<"$BAR_MODULES" | sort -u)
    [[ $have == "$want" ]] || bad+="$s missing [$(comm -23 <(echo "$want") <(echo "$have") | tr '\n' ' ')] extra [$(comm -13 <(echo "$want") <(echo "$have") | tr '\n' ' ')] "
  done
  if [[ -z $bad && -n $screens ]]; then
    section bar ok "$(wc -w <<<"$BAR_MODULES") modules on $(wc -w <<<"$screens") screens"
  else
    section bar fail "$bad"
  fi
}

check_notify() {
  local owner pid comm count osd
  export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
  "${QS[@]}" centerToggle > /dev/null; "${QS[@]}" centerToggle > /dev/null
  notify-send -a parity "torus parity" "hello from parity.sh"
  sleep 1
  owner=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetNameOwner s org.freedesktop.Notifications 2>/dev/null | awk '{print $2}' | tr -d '"')
  pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s "$owner" 2>/dev/null | awk '{print $2}')
  comm=$(cat "/proc/$pid/comm" 2>/dev/null)
  count=$("${QS[@]}" notifCount 2>/dev/null)
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ > /dev/null 2>&1
  sleep 0.5
  osd=$("${QS[@]}" osdVisible 2>/dev/null)
  local timed
  notify-send -t 3000 -a parity "timed" "three seconds"
  sleep 1.2
  timed=$("${QS[@]}" popupCount 2>/dev/null)
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- > /dev/null 2>&1
  if [[ $comm == qs || $comm == quickshell ]] && ((count >= 1)) && [[ $osd == true ]] && ((timed >= 1)); then
    section notify ok "owner=$comm count=$count osd=$osd timed-popup=$timed"
  else
    section notify fail "owner=$comm count=$count osd=$osd timed-popup=$timed"
  fi
}

frames() { "${QS[@]}" donutFrames "$1" 2>/dev/null; }

check_donut() {
  local screens main side a1 b1 a2 b2 a3 b3 pid t0 t1 tick cpu kitty
  screens=$(hyprctl monitors -j | jq -r '.[].name')
  main=$(head -1 <<<"$screens")
  side=$(sed -n 2p <<<"$screens")
  "${QS[@]}" wallpaper donut > /dev/null
  hyprctl clients -j | jq -r '.[].pid' | xargs -r kill 2> /dev/null
  sleep 1
  local up
  up=$(ps -o etimes= -p "$(pgrep -xo qs || pgrep -xo quickshell)" | tr -d ' ')
  ((up < 120)) && sleep $((120 - up))
  hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$main\" }))" > /dev/null
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "empty" }))' > /dev/null
  sleep 1
  local geo sd
  geo=$(hyprctl monitors -j | jq -r --arg m "$main" '.[] | select(.name == $m) | "\(.x + (.width / 2 | floor) - 120),\(.y + (.height / 2 | floor) - 120) 240x240"')
  grim -g "$geo" /tmp/parity-donut.png
  sd=$(magick /tmp/parity-donut.png -colorspace gray -format '%[fx:standard_deviation]' info: 2> /dev/null || echo 0)
  a1=$(frames "$main"); b1=$(frames "$side"); sleep 5
  a2=$(frames "$main"); b2=$(frames "$side")
  hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$main\" }))" > /dev/null
  hyprctl eval 'hl.exec_cmd("kitty --class parity-full")' > /dev/null
  for _ in $(seq 100); do hyprctl clients -j | jq -e 'any(.[]; .class == "parity-full")' > /dev/null && break; sleep 0.2; done
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:parity-full" }))' > /dev/null 2>&1
  for _ in $(seq 10); do
    hyprctl clients -j | jq -e 'any(.[]; .class == "parity-full" and .fullscreen > 0)' > /dev/null && break
    hyprctl eval 'hl.dispatch(hl.dsp.window.fullscreen())' > /dev/null
    sleep 0.5
  done
  sleep 1
  local fsdiag
  fsdiag="state[$("${QS[@]}" fullscreenState 2> /dev/null)] active[$(hyprctl activewindow -j | jq -r '"\(.class) ws\(.workspace.id) fs\(.fullscreen)"')]"
  a2=$(frames "$main"); b2=$(frames "$side"); sleep 4
  a3=$(frames "$main"); b3=$(frames "$side")
  kitty=$(hyprctl clients -j | jq -r '.[] | select(.class == "parity-full") | .pid')
  [[ -n $kitty ]] && kill "$kitty"
  local a4 a5
  sleep 2
  a4=$(frames "$main"); sleep 3; a5=$(frames "$main")
  pid=$(pgrep -xo qs || pgrep -xo quickshell)
  tick=$(getconf CLK_TCK)
  t0=$(awk '{print $14 + $15}' "/proc/$pid/stat"); sleep 30; t1=$(awk '{print $14 + $15}' "/proc/$pid/stat")
  cpu=$(awk -v d=$((t1 - t0)) -v t="$tick" 'BEGIN { printf "%.2f", d / t / 30 * 100 }')
  local ok=1
  ((a2 > a1)) || ok=0
  [[ -z $side ]] || ((b2 > b1)) || ok=0
  ((a3 == a2)) || ok=0
  ((a5 > a4)) || ok=0
  [[ -z $side ]] || ((b3 > b2)) || ok=0
  awk -v c="$cpu" -v max="${DONUT_CPU_MAX:-10}" 'BEGIN { exit !(c < max) }' || ok=0
  awk -v s="$sd" 'BEGIN { exit !(s > 0.03) }' || ok=0
  local detail="visible (contrast $sd), main $a1>$a2 then fullscreen $a2=$a3 then closed $a4>$a5, side $b1>$b2>$b3, qs cpu ${cpu}% of one core"
  if ((ok)); then section donut ok "$detail"; else section donut fail "$detail $fsdiag"; fi
}

check_dashboard() {
  local bad="" name
  for name in dashboard overview cheatsheet; do
    local fn
    case $name in dashboard) fn=dashboardToggle ;; overview) fn=overviewToggle ;; cheatsheet) fn=cheatSheetToggle ;; esac
    "${QS[@]}" "$fn" > /dev/null; sleep 0.4
    [[ $("${QS[@]}" isOpen "$name") == true ]] || bad+="$name-open "
    "${QS[@]}" "$fn" > /dev/null; sleep 0.2
    [[ $("${QS[@]}" isOpen "$name") == false ]] || bad+="$name-close "
  done
  hyprctl eval 'hl.exec_cmd("kitty --class parity-a")' > /dev/null
  hyprctl eval 'hl.exec_cmd("kitty --class parity-b")' > /dev/null
  sleep 2
  "${QS[@]}" altTab next > /dev/null; sleep 0.3
  [[ $("${QS[@]}" isOpen alttab) == true ]] || bad+="alttab-open "
  "${QS[@]}" altTab apply > /dev/null; sleep 0.3
  [[ $("${QS[@]}" isOpen alttab) == false ]] || bad+="alttab-apply "
  hyprctl clients -j | jq -r '.[] | select(.class | test("parity-")) | .pid' | xargs -r kill
  nmcli networking off > /dev/null 2>&1 || sudo nmcli networking off
  "${QS[@]}" weatherRefresh > /dev/null; sleep 4
  "${QS[@]}" dashboardToggle > /dev/null; sleep 0.5
  [[ $("${QS[@]}" isOpen dashboard) == true ]] || bad+="offline-dashboard "
  [[ $("${QS[@]}" weatherOk) == false ]] || bad+="offline-weather "
  "${QS[@]}" dashboardToggle > /dev/null
  nmcli networking on > /dev/null 2>&1 || sudo nmcli networking on
  if [[ -z $bad ]]; then section dashboard ok "dashboard, overview, cheatsheet, alt-tab, offline weather placeholder"; else section dashboard fail "$bad"; fi
}

check_look() {
  local bad="" accent g=org.gnome.desktop.interface
  accent=$(~/.local/bin/torus accent)
  [[ $(gsettings get $g gtk-theme) == "'adw-gtk3-dark'" ]] || bad+="gtk-theme "
  [[ $(gsettings get $g cursor-theme) == "'Bibata-Modern-Ice'" ]] || bad+="cursor "
  [[ $(gsettings get $g icon-theme) == "'Tela-circle-dracula'" ]] || bad+="icons "
  grep -q "theme=hyde-mocha" ~/.config/Kvantum/kvantum.kvconfig || bad+="kvantum "
  [[ -f ~/.config/Kvantum/hyde-mocha/hyde-mocha.svg ]] || bad+="kvantum-theme-missing "
  [[ -d /usr/share/icons/Bibata-Modern-Ice || -d ~/.local/share/icons/Bibata-Modern-Ice ]] || bad+="cursor-theme-missing "
  [[ -d /usr/share/icons/Tela-circle-dracula || -d ~/.local/share/icons/Tela-circle-dracula ]] || bad+="icon-theme-missing "
  local ff; ff=$(fastfetch --pipe false 2> /dev/null || true); grep -q 'marc' <<< "$ff" && grep -q '@@@@' <<< "$ff" || bad+="fastfetch-donut "
  git config --global --get-all include.path | grep -q torus/delta.gitconfig || bad+="delta "
  systemctl --user is-enabled torus-shell.service > /dev/null 2>&1 || bad+="shell-unit "
  [[ $(systemctl --user is-enabled dunst.service 2>&1) == masked ]] || bad+="dunst-not-masked "
  pacman -Q swaync > /dev/null 2>&1 && bad+="swaync-installed "
  if [[ -z $bad ]]; then section look ok "gtk, qt, cursor, icons, fastfetch donut, delta, shell unit, dunst masked (accent $accent)"; else section look fail "$bad"; fi
}

wait_lock() {
  local i
  for i in $(seq 30); do pgrep -x hyprlock > /dev/null && return 0; sleep 0.1; done
  return 1
}

unlock() {
  local i
  pkill -USR1 -x hyprlock
  for i in $(seq 40); do pgrep -x hyprlock > /dev/null || return 0; sleep 0.25; done
  return 1
}

check_lock() {
  local bad="" sid
  pgrep -x hypridle > /dev/null || { section lock fail "hypridle not running"; return; }
  hyprctl eval 'hl.exec_cmd("torus-lock")' > /dev/null
  if wait_lock; then sleep "${LOCK_HOLD:-1}"; unlock || bad+="keybind-unlock "; else bad+="keybind-path "; fi
  sid=$(loginctl list-sessions --no-legend | awk '$4 == "seat0" {print $1; exit}')
  loginctl lock-session "$sid"
  if wait_lock; then unlock || bad+="logind-unlock "; else bad+="logind-path "; fi
  if [[ -z $bad ]]; then
    section lock ok "keybind and logind paths lock ($(basename "$(readlink ~/.local/state/torus/hyprlock-layout.conf)"))"
  else
    section lock fail "$bad"
  fi
}

warm_kitty() {
  hyprctl eval 'hl.exec_cmd("kitty --class parity-warm")' > /dev/null
  for _ in $(seq 120); do hyprctl clients -j | jq -e 'any(.[]; .class == "parity-warm")' > /dev/null && break; sleep 0.5; done
  hyprctl clients -j | jq -r '.[] | select(.class == "parity-warm") | .pid' | xargs -r kill
  sleep 1
}

warm_kitty

case ${1:-all} in
  lock) check_lock ;;
  look) check_look ;;
  dashboard) check_dashboard ;;
  donut) check_donut ;;
  notify) check_notify ;;
  binds) check_binds ;;
  bar) check_bar ;;
  all) check_binds; check_bar; check_notify; check_donut; check_dashboard; check_look; check_lock ;;
  *) echo "unknown section: $1" >&2; exit 1 ;;
esac
echo "parity: $passed/$total"
((passed == total))
