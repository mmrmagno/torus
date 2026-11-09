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

BAR_MODULES="cpu memory cpuinfo gpuinfo idle clock workspaces taskbar sunset network audio mic updates keyhint privacy record tray wallpaper accent clipboard menu notifications power"

check_bar() {
  local out screens bad=""
  out=$("${QS[@]}" modules 2>&1)
  screens=$(hyprctl monitors -j | jq -r '.[].name' | sort)
  for s in $screens; do
    local have want
    have=$(tr ';' '\n' <<<"$out" | grep "^$s:" | cut -d: -f2 | tr ',' '\n' | grep -vx media | sort -u)
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
  timeout 5 notify-send -t 3000 -a parity -A ok=OK "timed" "three seconds" > /dev/null 2>&1 &
  sleep 1.2
  timed=$("${QS[@]}" popupCount 2>/dev/null)
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- > /dev/null 2>&1
  if [[ $comm == qs || $comm == quickshell ]] && ((count >= 1)) && [[ $osd == true ]] && ((timed >= 1)); then
    section notify ok "owner=$comm count=$count osd=$osd timed-popup=$timed"
  else
    section notify fail "owner=$comm count=$count osd=$osd timed-popup=$timed"
  fi
}

island_on() {
  local want=$1 i
  for i in $(seq 1 30); do
    [[ $("${QS[@]}" islandState 2>/dev/null) == *"$want"* ]] && return 0
    sleep 0.2
  done
  return 1
}

check_island() {
  local screens focused st plain bad="" rec
  export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
  screens=$(hyprctl monitors -j | jq -r '.[].name' | sort)
  focused=$(hyprctl monitors -j | jq -r '.[] | select(.focused).name')
  sleep 4
  st=$("${QS[@]}" islandState 2>/dev/null)
  for s in $screens; do [[ $st == *"$s:"* ]] || bad+="no-island-on-$s "; done
  local before
  before=$("${QS[@]}" popupCount 2>/dev/null)
  notify-send -a parity "island" "plain notification"
  island_on "$focused:notification" || bad+="no-notification-state "
  plain=$("${QS[@]}" popupCount 2>/dev/null)
  ((plain <= before)) || bad+="plain-notification-popped-up "
  sleep 4.5
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ > /dev/null 2>&1
  island_on "$focused:osd" || bad+="no-osd-state "
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- > /dev/null 2>&1
  sleep 2
  rec="${XDG_STATE_HOME:-$HOME/.local/state}/torus/recording"
  date +%s > "$rec"
  island_on "$focused:recording" || bad+="no-recording-state "
  : > "$rec"
  local vids="${XDG_VIDEOS_DIR:-$HOME/Videos}" n
  mkdir -p "$vids"; : > "$vids/torus-parity.mp4"; sleep 1
  n=$("${QS[@]}" recordingsCount 2>/dev/null)
  ((n >= 1)) || bad+="recordings-list-empty "
  rm -f "$vids/torus-parity.mp4"
  island_on "$focused:idle" || island_on "$focused:hidden" || bad+="still-recording "
  st=$("${QS[@]}" islandState 2>/dev/null)
  if [[ -z $bad ]]; then section island ok "states notification, osd, recording, idle; now $st"; else section island fail "$bad now: $st"; fi
}

check_groups() {
  local bad="" g r
  export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
  "${QS[@]}" clearNotifs > /dev/null 2>&1
  for i in 1 2 3; do notify-send -a grouped "grouped $i" "body $i"; done
  notify-send -a solo "solo" "alone"
  gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications \
    --method org.freedesktop.Notifications.Notify chat 0 "" "message" "reply to me" '["inline-reply", "Reply"]' '{}' 0 > /dev/null
  sleep 1
  g=$("${QS[@]}" notifGroups 2>/dev/null | tail -n 1)
  [[ $g == "chat:1;solo:1;grouped:3" ]] || bad+="groups:[$g] "
  r=$("${QS[@]}" notifReplyable 2>/dev/null | tail -n 1)
  [[ $r == 1 ]] || bad+="replyable:[$r] "
  "${QS[@]}" centerToggle > /dev/null 2>&1; sleep 1
  local c1 c2
  c1=$("${QS[@]}" notifCardsMade 2>/dev/null | tail -n 1)
  notify-send -a another "another" "one more"; sleep 1
  c2=$("${QS[@]}" notifCardsMade 2>/dev/null | tail -n 1)
  ((c2 - c1 == 1)) || bad+="cards-rebuilt:$((c2 - c1)) "
  "${QS[@]}" centerToggle > /dev/null 2>&1
  "${QS[@]}" clearNotifs > /dev/null 2>&1
  if [[ -z $bad ]]; then section groups ok "grouped by app newest first [$g], inline reply offered"; else section groups fail "$bad"; fi
}

check_clip() {
  local bad="" n got img=/tmp/parity-clip.png
  export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
  magick -size 64x40 xc:'#cba6f7' "$img"
  wl-copy --type image/png < "$img"; sleep 0.6
  printf 'parity clip %s' "$$" | wl-copy; sleep 0.6
  rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/torus/clip"
  "${QS[@]}" clipToggle > /dev/null 2>&1; sleep 2
  n=$("${QS[@]}" clipCount 2>/dev/null | tail -n 1)
  ((n >= 2)) || bad+="count:[$n] "
  ls "${XDG_CACHE_HOME:-$HOME/.cache}"/torus/clip/*.img > /dev/null 2>&1 || bad+="no-thumbnail "
  "${QS[@]}" clipFilter "prtyclp$$" > /dev/null 2>&1; sleep 0.3
  n=$("${QS[@]}" clipCount 2>/dev/null | tail -n 1)
  [[ $n == 1 ]] || bad+="fuzzy:[$n] "
  printf 'something else' | wl-copy; sleep 0.3
  "${QS[@]}" clipCopy 0 > /dev/null 2>&1; sleep 0.8
  got=$(wl-paste --no-newline 2>/dev/null)
  [[ $got == "parity clip $$" ]] || bad+="copy:[$got] "
  [[ $("${QS[@]}" isOpen clip 2>/dev/null | tail -n 1) == false ]] || bad+="still-open "
  cliphist wipe
  "${QS[@]}" clipToggle > /dev/null 2>&1; sleep 2; "${QS[@]}" clipToggle > /dev/null 2>&1
  [[ -z $(ls -A "${XDG_CACHE_HOME:-$HOME/.cache}/torus/clip" 2>/dev/null) ]] || bad+="thumbnails-outlive-wipe "
  if [[ -z $bad ]]; then section clip ok "history with image thumbnail, fuzzy filter, copy closes panel"; else section clip fail "$bad"; fi
}

check_ai() {
  local bad="" st mock pid reply
  command -v python3 > /dev/null || { section ai fail "python3 missing (mock server)"; return; }
  "${QS[@]}" aiRefresh > /dev/null 2>&1; sleep 2
  st=$("${QS[@]}" aiStatus 2>/dev/null | tail -n 1)
  [[ $st == offline ]] || bad+="offline:[$st] "
  mock=$(mktemp)
  cat > "$mock" <<'PY'
import http.server, json, time
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        body = json.dumps({"models": [{"name": "mock:1b"}, {"name": "mock:7b"}]}).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json"); self.end_headers(); self.wfile.write(body)
    def do_POST(self):
        req = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        self.send_response(200); self.send_header("Content-Type", "application/x-ndjson"); self.end_headers()
        last = req["messages"][-1]["content"]
        for part in ["hello ", "from ", req["model"], " re: ", last]:
            self.wfile.write((json.dumps({"message": {"role": "assistant", "content": part}, "done": False}) + "\n").encode()); self.wfile.flush(); time.sleep(0.1)
        self.wfile.write((json.dumps({"done": True}) + "\n").encode())
http.server.HTTPServer(("127.0.0.1", 11434), H).serve_forever()
PY
  python3 "$mock" 2> /dev/null & pid=$!
  sleep 1
  "${QS[@]}" aiRefresh > /dev/null 2>&1; sleep 2
  st=$("${QS[@]}" aiStatus 2>/dev/null | tail -n 1)
  [[ $st == "online mock:1b mock:1b,mock:7b" ]] || bad+="online:[$st] "
  "${QS[@]}" aiAsk "ping" > /dev/null 2>&1; sleep 3
  reply=$("${QS[@]}" aiLast 2>/dev/null | tail -n 1)
  [[ $reply == "hello from mock:1b re: ping" ]] || bad+="reply:[$reply] "
  "${QS[@]}" aiAsk "first" > /dev/null 2>&1; sleep 0.15; "${QS[@]}" aiAsk "second" > /dev/null 2>&1; sleep 3
  reply=$("${QS[@]}" aiLast 2>/dev/null | tail -n 1)
  [[ $reply == "hello from mock:1b re: second" ]] || bad+="race-reply:[$reply] "
  reply=$("${QS[@]}" aiError 2>/dev/null | tail -n 1)
  [[ -z $reply ]] || bad+="race-error:[$reply] "
  kill "$pid" 2> /dev/null; rm -f "$mock"
  "${QS[@]}" aiRefresh > /dev/null 2>&1
  if [[ -z $bad ]]; then section ai ok "offline hint, models from /api/tags, streamed reply"; else section ai fail "$bad"; fi
}

check_polkit() {
  local bad="" st i ok=/tmp/torus-pk-ok
  [[ -n ${LOCK_PW:-} ]] || { section polkit fail "LOCK_PW not set"; return; }
  st=$("${QS[@]}" polkitState 2>/dev/null | tail -n 1)
  [[ $st == registered ]] || bad+="state:[$st] "
  systemctl --user is-active --quiet hyprpolkitagent.service && bad+="hyprpolkitagent-still-running "
  sudo rm -f "$ok"
  hyprctl eval "hl.exec_cmd(\"pkexec --disable-internal-agent touch $ok\")" > /dev/null
  for i in $(seq 40); do [[ $("${QS[@]}" polkitState 2>/dev/null | tail -n 1) == active ]] && break; sleep 0.25; done
  [[ $("${QS[@]}" polkitState 2>/dev/null | tail -n 1) == active ]] || bad+="no-dialog "
  sleep 1
  type_pw "$LOCK_PW"
  for i in $(seq 40); do [[ -e $ok ]] && break; sleep 0.25; done
  [[ -e $ok ]] || bad+="pkexec-not-authorized "
  sudo rm -f "$ok"
  systemctl --user stop torus-shell.service; sleep 2
  systemctl --user is-active --quiet hyprpolkitagent.service || bad+="no-fallback-agent "
  systemctl --user start torus-shell.service; sleep 7
  systemctl --user is-active --quiet hyprpolkitagent.service && bad+="fallback-not-stopped "
  [[ $("${QS[@]}" polkitState 2>/dev/null | tail -n 1) == registered ]] || bad+="not-reregistered "
  if [[ -z $bad ]]; then section polkit ok "shell agent registered, pkexec authorized through the dialog, hyprpolkitagent covers a stopped shell"; else section polkit fail "$bad"; fi
}

corners_on() { hyprctl layers -j | jq --arg m "$1" '[.[$m].levels[][] | select(.namespace == "torus-corner")] | length'; }

check_corners() {
  local bad="" main n s
  for s in $(hyprctl monitors -j | jq -r '.[].name'); do
    n=$(corners_on "$s"); [[ $n == 4 ]] || bad+="$s:$n "
  done
  main=$(hyprctl monitors -j | jq -r '.[0].name')
  hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$main\" }))" > /dev/null
  hyprctl eval 'hl.exec_cmd("kitty --class parity-corner")' > /dev/null
  for _ in $(seq 100); do hyprctl clients -j | jq -e 'any(.[]; .class == "parity-corner")' > /dev/null && break; sleep 0.2; done
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:parity-corner" }))' > /dev/null 2>&1
  for _ in $(seq 10); do
    hyprctl clients -j | jq -e 'any(.[]; .class == "parity-corner" and .fullscreen > 0)' > /dev/null && break
    hyprctl eval 'hl.dispatch(hl.dsp.window.fullscreen())' > /dev/null
    sleep 0.5
  done
  sleep 1.5
  n=$(corners_on "$main"); [[ $n == 0 ]] || bad+="fullscreen:$n "
  hyprctl clients -j | jq -r '.[] | select(.class == "parity-corner") | .pid' | xargs -r kill
  sleep 1.5
  n=$(corners_on "$main"); [[ $n == 4 ]] || bad+="after:$n "
  if [[ -z $bad ]]; then section corners ok "4 rounded corners per screen, hidden under fullscreen"; else section corners fail "$bad"; fi
}

check_widgets() {
  local bad="" mons land port shown want
  mons=$(hyprctl monitors -j)
  land=$(jq -r '.[] | select(((.transform % 2) == 0 and .width >= .height) or ((.transform % 2) == 1 and .height >= .width)) | .name' <<<"$mons" | sort | xargs)
  port=$(jq -r '.[].name' <<<"$mons" | sort | xargs)
  "${QS[@]}" widgets landscape > /dev/null 2>&1; sleep 1
  shown=$("${QS[@]}" widgetsShown 2>/dev/null | tail -n 1)
  [[ $shown == "$land" ]] || bad+="landscape:[$shown]!=[$land] "
  "${QS[@]}" widgets all > /dev/null 2>&1; sleep 1
  shown=$("${QS[@]}" widgetsShown 2>/dev/null | tail -n 1)
  [[ $shown == "$port" ]] || bad+="all:[$shown]!=[$port] "
  "${QS[@]}" widgets off > /dev/null 2>&1; sleep 1
  shown=$("${QS[@]}" widgetsShown 2>/dev/null | tail -n 1)
  [[ -z $shown ]] || bad+="off:[$shown] "
  want=$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/torus/widgets" 2>/dev/null)
  [[ $want == off ]] || bad+="not-persisted "
  "${QS[@]}" widgets landscape > /dev/null 2>&1
  if [[ -z $bad ]]; then section widgets ok "landscape [$land], all, off, persisted"; else section widgets fail "$bad"; fi
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
  local cpumax=${DONUT_CPU_MAX:-10}
  grep -qs -e kms_swrast -e llvmpipe "$XDG_RUNTIME_DIR"/hypr/*/hyprland.log && cpumax=${DONUT_CPU_MAX:-70}
  awk -v c="$cpu" -v max="$cpumax" 'BEGIN { exit !(c < max) }' || ok=0
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
locked_is() {
  local want=$1 i
  for i in $(seq 60); do
    [[ $("${QS[@]}" isLocked 2>/dev/null) == "$want" ]] && return 0
    sleep 0.25
  done
  return 1
}
type_pw() {
  wtype "$1"
  sleep 0.2
  wtype -k Return
}

check_lock() {
  local bad="" sid state=${XDG_STATE_HOME:-$HOME/.local/state}/torus
  pgrep -x hypridle > /dev/null || { section lock fail "hypridle not running"; return; }
  [[ -n ${LOCK_PW:-} ]] || { section lock fail "LOCK_PW not set"; return; }
  command -v wtype > /dev/null || { section lock fail "wtype missing (VM fixture)"; return; }
  rm -f "$state/lock"
  hyprctl eval 'hl.exec_cmd("torus-lock")' > /dev/null
  if locked_is true; then
    pgrep -x hyprlock > /dev/null && bad+="hyprlock-instead-of-shell "
    [[ -n $(ls "$XDG_RUNTIME_DIR"/torus-lock/*.png 2>/dev/null) ]] || bad+="no-lock-screenshot "
    local t1 t2
    t1=$("${QS[@]}" donutClock 2>/dev/null | cut -d: -f2); sleep 1; t2=$("${QS[@]}" donutClock 2>/dev/null | cut -d: -f2)
    ((t2 > t1)) || bad+="lock-donut-stopped($("${QS[@]}" donutClock 2>/dev/null)) "
    sleep 31
    t1=$("${QS[@]}" donutClock 2>/dev/null | cut -d: -f2); sleep 1; t2=$("${QS[@]}" donutClock 2>/dev/null | cut -d: -f2)
    ((t2 == t1)) || bad+="lock-donut-never-sleeps "
    wtype -k Shift_L; sleep 0.5
    t1=$("${QS[@]}" donutClock 2>/dev/null | cut -d: -f2); sleep 1; t2=$("${QS[@]}" donutClock 2>/dev/null | cut -d: -f2)
    ((t2 > t1)) || bad+="lock-donut-no-wake "
    type_pw "not-the-password"
    sleep 4
    locked_is true || bad+="wrong-password-unlocked "
    type_pw "$LOCK_PW"
    locked_is false || bad+="shell-unlock "
    [[ -z $(ls "$XDG_RUNTIME_DIR"/torus-lock/ 2>/dev/null) ]] || bad+="lock-files-left "
  else
    bad+="keybind-path "
  fi
  local keys=/tmp/parity-keys
  rm -f "$keys"
  hyprctl eval "hl.exec_cmd(\"kitty --class parity-keys sh -c 'cat > $keys'\")" > /dev/null
  for _ in $(seq 100); do hyprctl clients -j | jq -e 'any(.[]; .class == "parity-keys")' > /dev/null && break; sleep 0.2; done
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:parity-keys" }))' > /dev/null 2>&1
  sleep 1
  hyprctl eval 'hl.exec_cmd("torus-lock")' > /dev/null
  if locked_is true; then
    local qml loads
    qml=$(readlink -f ~/.config/quickshell/torus/shell.qml)
    loads=$(journalctl --user -u torus-shell --no-pager -o cat | grep -c "Configuration Loaded")
    echo >> "$qml"
    for _ in $(seq 25); do wtype "x"; sleep 0.12; done
    sed -i '$ d' "$qml"
    for _ in $(seq 25); do wtype "x"; sleep 0.12; done
    sleep 2
    (( $(journalctl --user -u torus-shell --no-pager -o cat | grep -c "Configuration Loaded") > loads )) || bad+="reload-not-triggered "
    locked_is true || bad+="reload-unlocked "
    wtype -k Escape
    type_pw "$LOCK_PW"
    locked_is false || bad+="reload-unlock "
    sleep 0.5
    [[ ! -s $keys ]] || bad+="keys-leaked-during-reload($(wc -c < "$keys")) "
  else
    bad+="reload-lock "
  fi
  hyprctl clients -j | jq -r '.[] | select(.class == "parity-keys") | .pid' | xargs -r kill
  sid=$(loginctl list-sessions --no-legend | awk '$4 == "seat0" {print $1; exit}')
  loginctl lock-session "$sid"
  if locked_is true; then
    pkill -9 -x qs
    sleep 4
    locked_is true || bad+="crash-unlocked "
    sleep 2
    type_pw "$LOCK_PW"
    locked_is false || bad+="logind-unlock "
  else
    bad+="logind-path "
  fi
  hyprctl eval 'hl.exec_cmd("hyprlock")' > /dev/null
  if wait_lock; then
    sleep 1
    "${QS[@]}" lock > /dev/null 2>&1
    if locked_is true; then
      sleep 3
      type_pw "$LOCK_PW"
      locked_is false || { sleep 2; type_pw "$LOCK_PW"; locked_is false; } || bad+="takeover-unlock "
    else
      bad+="no-takeover "
    fi
    pkill -x hyprlock
  else
    bad+="no-hyprlock "
  fi
  sleep 1
  hyprctl eval 'hl.exec_cmd("torus-lock")' > /dev/null
  if locked_is true; then
    hyprctl eval 'hl.exec_cmd("hyprlock")' > /dev/null
    wait_lock && sleep 1
    unlock || bad+="hyprlock-unlock "
    sleep 1
    locked_is true || bad+="shell-lock-lost-under-hyprlock "
    systemctl --user restart torus-shell.service
    sleep 5
    locked_is true || bad+="restart-unlocked "
    type_pw "$LOCK_PW"
    locked_is false || bad+="unlock-after-hyprlock "
  else
    bad+="relock "
  fi
  systemctl --user stop torus-shell.service
  hyprctl eval 'hl.exec_cmd("torus-lock")' > /dev/null
  if wait_lock; then sleep "${LOCK_HOLD:-1}"; unlock || bad+="fallback-unlock "; else bad+="no-hyprlock-fallback "; fi
  systemctl --user start torus-shell.service
  sleep 4
  if [[ -z $bad ]]; then
    section lock ok "shell lock: keybind, wrong password, PAM unlock, logind, survives a config reload, a shell crash and a hyprlock takeover; hyprlock fallback ($(basename "$(readlink "$state/hyprlock-layout.conf")"))"
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

check_media() {
  local bad="" tone=/tmp/parity-tone.ogg f1 f2 n line
  command -v mpv > /dev/null || { section media fail "mpv missing (VM fixture installs mpv mpv-mpris ffmpeg)"; return; }
  [[ -f $tone ]] || ffmpeg -loglevel error -f lavfi -i "sine=frequency=110:duration=213" -f lavfi -i "sine=frequency=880:duration=213" -filter_complex "[0][1]amix=inputs=2,volume=4" -metadata artist="Rick Astley" -metadata title="Never Gonna Give You Up" -metadata album="Whenever You Need Somebody" -c:a libvorbis "$tone"
  pkill -x mpv 2> /dev/null || true
  mpv --no-video --really-quiet --start=40 "$tone" > /dev/null 2>&1 &
  local mp=$!
  sleep 6
  f1=$("${QS[@]}" visualizerFrames); sleep 2; f2=$("${QS[@]}" visualizerFrames)
  ((f2 > f1)) || bad+="visualizer-not-running "
  pgrep -x cava > /dev/null || bad+="cava-not-running "
  n=$("${QS[@]}" lyricsCount)
  ((n > 0)) || bad+="no-lyrics "
  [[ $("${QS[@]}" islandState) == *"state:media"* ]] || bad+="island-not-media "
  line=$("${QS[@]}" lyricsLine)
  [[ -n $line ]] || bad+="no-current-line "
  kill "$mp" 2> /dev/null
  sleep 3
  pgrep -x cava > /dev/null && bad+="cava-still-running-when-idle "
  if [[ -z $bad ]]; then section media ok "visualizer $f1>$f2, $n lyric lines, now: $line, cava stops when idle"; else section media fail "$bad"; fi
}

check_night() {
  local bad="" t
  [[ $("${QS[@]}" nightLight 2>/dev/null) == true ]] && "${QS[@]}" nightLightToggle > /dev/null && sleep 1
  "${QS[@]}" nightLightToggle > /dev/null; sleep 1.5
  [[ $("${QS[@]}" nightLight 2>/dev/null) == true ]] || bad+="on-not-shown "
  t=$(hyprctl hyprsunset temperature 2>/dev/null)
  [[ $t == 5500 ]] || bad+="temperature-$t "
  "${QS[@]}" nightLightToggle > /dev/null; sleep 1.5
  [[ $("${QS[@]}" nightLight 2>/dev/null) == false ]] || bad+="off-snaps-back "
  if [[ -z $bad ]]; then section night ok "toggles on (5500 K) and stays off"; else section night fail "$bad"; fi
}

check_palette() {
  local bad="" r
  "${QS[@]}" paletteQuery "=2*21" > /dev/null; sleep 1.5
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  [[ $r == calc:42* ]] || bad+="calc[$r] "
  "${QS[@]}" paletteQuery "kitt" > /dev/null; sleep 0.5
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  [[ $r == *app:kitty* ]] || bad+="app[$r] "
  "${QS[@]}" paletteQuery "night" > /dev/null; sleep 0.5
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  [[ $r == action:Night\ light* ]] || bad+="action[$r] "
  mkdir -p ~/dev/kb/parity && echo "the parity needle lives here" > ~/dev/kb/parity/needle.md
  "${QS[@]}" paletteQuery "?parity needle" > /dev/null; sleep 1.5
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  [[ $r == kb:*needle* ]] || bad+="kb[$r] "
  rm -rf ~/dev/kb/parity
  "${QS[@]}" paletteQuery ":grinning" > /dev/null; sleep 0.5
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  [[ $r == emoji:* ]] || bad+="emoji[$r] "
  echo x > ~/parity-needle-file.txt
  "${QS[@]}" paletteQuery "/parity-needle" > /dev/null; sleep 1.5
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  [[ $r == file:parity-needle-file.txt* ]] || bad+="files[$r] "
  "${QS[@]}" paletteQuery "/" > /dev/null; sleep 0.5
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  [[ -z $r ]] || bad+="stale-files[$r] "
  rm -f ~/parity-needle-file.txt
  "${QS[@]}" paletteQuery "=2+2" > /dev/null; sleep 1.5
  "${QS[@]}" paletteQuery "=2+3" > /dev/null
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  [[ $r != *calc:4* ]] || bad+="stale-calc "
  "${QS[@]}" paletteQuery "=2-5" > /dev/null
  for _ in $(seq 30); do [[ $("${QS[@]}" paletteResults 2>/dev/null | tail -n 1) == calc:* ]] && break; sleep 0.2; done
  "${QS[@]}" paletteRun 0 > /dev/null; sleep 0.5
  [[ $(wl-paste -n 2>/dev/null) == "-3" ]] || bad+="calc-copy[$(wl-paste -n 2>/dev/null)] "
  "${QS[@]}" paletteQuery "kitt" > /dev/null; sleep 0.3
  "${QS[@]}" paletteToggle > /dev/null; sleep 0.3
  [[ $("${QS[@]}" isOpen palette 2>/dev/null | tail -n 1) == false ]] || bad+="still-open "
  [[ -z $("${QS[@]}" paletteResults 2>/dev/null | tail -n 1) ]] || bad+="results-while-closed "
  grep -qE '"(w|f|kb):' "${XDG_STATE_HOME:-$HOME/.local/state}/torus/palette.json" 2>/dev/null && bad+="remembers-windows-or-files "
  if [[ -z $bad ]]; then section palette ok "calc, apps, actions, kb, emoji, pass hint, closes"; else section palette fail "$bad"; fi
}

check_focus() {
  local bad="" was l
  was=$("${QS[@]}" dnd 2>/dev/null | tail -n 1)
  "${QS[@]}" focusStart 0.05 > /dev/null; sleep 1
  [[ $("${QS[@]}" dnd 2>/dev/null | tail -n 1) == true ]] || bad+="no-dnd "
  [[ $("${QS[@]}" islandState 2>/dev/null | tail -n 1) == *focus* ]] || bad+="island[$("${QS[@]}" islandState 2>/dev/null | tail -n 1)] "
  l=$("${QS[@]}" focusLeft 2>/dev/null | tail -n 1)
  [[ $l =~ ^[0-9]+$ ]] && ((l > 0 && l <= 3)) || bad+="left[$l] "
  sleep 3
  [[ $("${QS[@]}" focusLeft 2>/dev/null | tail -n 1) == -1 ]] || bad+="did-not-finish "
  [[ $("${QS[@]}" dnd 2>/dev/null | tail -n 1) == "$was" ]] || bad+="dnd-not-restored "
  if [[ -z $bad ]]; then section focus ok "dnd on, island ring, finishes, dnd restored"; else section focus fail "$bad"; fi
}

check_switch() {
  local bad="" side ws pids="" i sz cols rows w h sw sh
  side=$(hyprctl monitors -j | jq -r '.[] | select(.transform == 1 or .transform == 3) | .name' | head -1)
  [[ -n $side ]] || { section switch fail "no portrait screen"; return; }
  hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$side\" }))" > /dev/null
  for i in $(seq 9); do hyprctl eval 'hl.exec_cmd("kitty --class parity-switch")' > /dev/null; done
  for _ in $(seq 100); do [[ $(hyprctl clients -j | jq '[.[] | select(.class == "parity-switch")] | length') -ge 9 ]] && break; sleep 0.2; done
  sleep 1
  "${QS[@]}" altTab next > /dev/null; sleep 0.8
  sz=$("${QS[@]}" altTabSize 2>/dev/null | tail -n 1)
  IFS=: read -r cols rows w h dims <<< "$sz"
  sw=${dims%x*}; sh=${dims#*x}
  ((cols * rows >= 9)) || bad+="not-all-tiles[$sz] "
  ((w <= sw && h <= sh)) || bad+="off-screen[$sz] "
  "${QS[@]}" altTab apply > /dev/null; sleep 0.3
  local before after
  before=$(hyprctl activewindow -j | jq -r .address)
  "${QS[@]}" altTab next > /dev/null; sleep 0.4
  "${QS[@]}" altTab cancel > /dev/null; sleep 0.2
  "${QS[@]}" altTab apply > /dev/null; sleep 0.3
  after=$(hyprctl activewindow -j | jq -r .address)
  [[ $before == "$after" ]] || bad+="cancel-switched "
  [[ $("${QS[@]}" isOpen alttab 2>/dev/null | tail -n 1) == false ]] || bad+="cancel-left-open "
  before=$(hyprctl activewindow -j | jq -r .address)
  "${QS[@]}" altTab apply > /dev/null; "${QS[@]}" altTab next > /dev/null; sleep 0.4
  after=$(hyprctl activewindow -j | jq -r .address)
  [[ $before != "$after" ]] || bad+="quick-tap-no-switch "
  [[ $("${QS[@]}" isOpen alttab 2>/dev/null | tail -n 1) == false ]] || { bad+="quick-tap-left-open "; "${QS[@]}" altTab apply > /dev/null; }
  hyprctl clients -j | jq -r '.[] | select(.class == "parity-switch") | .pid' | xargs -r kill
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "1" }))' > /dev/null
  "${QS[@]}" overviewToggle > /dev/null; sleep 1
  wtype 3; sleep 0.8
  ws=$(hyprctl activeworkspace -j | jq -r .id)
  [[ $ws == 3 ]] || bad+="overview-key[$ws] "
  [[ $("${QS[@]}" isOpen overview 2>/dev/null | tail -n 1) == false ]] || { bad+="overview-open "; "${QS[@]}" overviewToggle > /dev/null; }
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "1" }))' > /dev/null
  if [[ -z $bad ]]; then section switch ok "alt-tab fits 9 windows on the portrait screen [$sz], overview number key"; else section switch fail "$bad"; fi
}

check_pass() {
  local bad="" r stub=~/.local/bin/pass-cli
  [[ -e $stub && ! -L $stub && $(head -c 40 "$stub") != *parity* ]] && { section pass fail "real pass-cli in the way"; return; }
  printf '#!/usr/bin/env bash\n# parity stub\ncase "$1 $2" in\n  "vault list") echo "- [SID_A==]: Personal" ;;\n  "item list") echo "- [IID_1==]: github.com (state=Active)" ;;\n  "item view") echo "parity-s3cret" ;;\n  "item totp") echo "totp: 654321" ;;\nesac\n' > "$stub"; chmod +x "$stub"
  "${QS[@]}" paletteQuery "p git" > /dev/null; sleep 2
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  [[ $r == pass:github.com* ]] || bad+="list[$r] "
  "${QS[@]}" paletteRun 0 > /dev/null; sleep 0.3
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  [[ $r == field:Password* ]] || bad+="fields[$r] "
  [[ $("${QS[@]}" isOpen palette 2>/dev/null | tail -n 1) == true ]] || bad+="closed-too-early "
  "${QS[@]}" paletteRun 0 > /dev/null; sleep 1.5
  [[ $(wl-paste -n 2>/dev/null) == parity-s3cret ]] || bad+="not-copied "
  cliphist list 2>/dev/null | grep -q parity-s3cret && bad+="in-clipboard-history "
  [[ $("${QS[@]}" isOpen palette 2>/dev/null | tail -n 1) == false ]] || bad+="still-open "
  rm -f "$stub"; wl-copy --clear
  if [[ -z $bad ]]; then section pass ok "names listed, field step, copied sensitive, not in history"; else section pass fail "$bad"; fi
}

check_mixer() {
  local bad="" r pid
  mpv --no-video --loop=inf --volume=40 /usr/share/sounds/freedesktop/stereo/complete.oga > /dev/null 2>&1 &
  pid=$!
  sleep 2
  "${QS[@]}" dashboardToggle > /dev/null; sleep 1
  r=$("${QS[@]}" mixerStreams 2>/dev/null | tail -n 1)
  [[ $r == *mpv* ]] || bad+="stream-missing[$r] "
  "${QS[@]}" dashboardToggle > /dev/null
  kill "$pid" 2>/dev/null
  if [[ -z $bad ]]; then section mixer ok "playing app listed [$r]"; else section mixer fail "$bad"; fi
}

check_shot() {
  local bad="" st
  torus-shot p; sleep 0.8
  st=$("${QS[@]}" islandState 2>/dev/null | tail -n 1)
  [[ $st == *shot* ]] || bad+="island[$st] "
  pgrep -x satty > /dev/null && { bad+="satty-opened "; pkill -x satty; }
  [[ -n $(ls ~/Pictures/Screenshots/torus-*.png 2>/dev/null) ]] || bad+="no-file "
  sleep 6.5
  st=$("${QS[@]}" islandState 2>/dev/null | tail -n 1)
  [[ $st != *shot* ]] || bad+="never-hides "
  if [[ -z $bad ]]; then section shot ok "island shows the screenshot, hides after 6 s, no editor forced"; else section shot fail "$bad"; fi
}

check_panels() {
  local bad="" r
  "${QS[@]}" networkToggle > /dev/null; sleep 3
  [[ $("${QS[@]}" isOpen network 2>/dev/null | tail -n 1) == true ]] || bad+="network-closed "
  r=$("${QS[@]}" networkState 2>/dev/null | tail -n 1)
  [[ $r != -:* ]] || bad+="no-wired[$r] "
  "${QS[@]}" networkToggle > /dev/null
  "${QS[@]}" updatesToggle > /dev/null; sleep 8
  r=$("${QS[@]}" updatesState 2>/dev/null | tail -n 1)
  [[ $r =~ ^[0-9]+:[1-9] ]] || bad+="updates[$r] "
  "${QS[@]}" updatesToggle > /dev/null
  if [[ -z $bad ]]; then section panels ok "network panel sees the wired link, update centre lists updates and arch news [$r]"; else section panels fail "$bad"; fi
}

check_pins() {
  local bad="" r
  printf 'parity pinned text' | wl-copy; sleep 1
  "${QS[@]}" clipToggle > /dev/null; sleep 1.5
  "${QS[@]}" clipPin 0 > /dev/null; sleep 1
  [[ $("${QS[@]}" clipPinned 2>/dev/null | tail -n 1) == *"parity pinned text"* ]] || bad+="not-pinned "
  "${QS[@]}" clipToggle > /dev/null
  cliphist wipe; printf 'something else' | wl-copy; sleep 1
  "${QS[@]}" clipToggle > /dev/null; sleep 1.5
  "${QS[@]}" clipCopy 0 > /dev/null; sleep 0.8
  r=$(wl-paste -n 2>/dev/null)
  [[ $r == "parity pinned text" ]] || bad+="pin-lost[$r] "
  "${QS[@]}" clipToggle > /dev/null; sleep 1
  "${QS[@]}" clipPin 0 > /dev/null; sleep 0.5
  [[ -z $("${QS[@]}" clipPinned 2>/dev/null | tail -n 1) ]] || bad+="unpin-failed "
  "${QS[@]}" clipToggle > /dev/null
  if [[ -z $bad ]]; then section pins ok "pinned entry survives a history wipe and copies back"; else section pins fail "$bad"; fi
}

check_smart() {
  local bad="" was h r
  "${QS[@]}" clearNotifs > /dev/null
  for _ in 1 2 3; do notify-send -a parity "Build failed" "job 42"; sleep 0.4; done; sleep 1
  r=$("${QS[@]}" notifCount 2>/dev/null | tail -n 1)
  [[ $r == 1 ]] || bad+="not-collapsed[$r] "
  [[ $("${QS[@]}" notifRepeatMax 2>/dev/null | tail -n 1) == 3 ]] || bad+="no-x3 "
  "${QS[@]}" paletteQuery "n build" > /dev/null; sleep 0.5
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  [[ $r == notification:Build\ failed* ]] || bad+="history[$r] "
  "${QS[@]}" paletteToggle > /dev/null
  h=$(date +%-H)
  "${QS[@]}" quietSet $(( (h + 2) % 24 )) $(( (h + 3) % 24 )) > /dev/null
  was=$("${QS[@]}" dnd 2>/dev/null | tail -n 1)
  [[ $("${QS[@]}" quietSet "$h" $(( (h + 1) % 24 )) 2>/dev/null | tail -n 1) == true ]] || bad+="quiet-not-active "
  [[ $("${QS[@]}" dnd 2>/dev/null | tail -n 1) == true ]] || bad+="quiet-no-dnd "
  "${QS[@]}" quietSet $(( (h + 2) % 24 )) $(( (h + 3) % 24 )) > /dev/null
  [[ $("${QS[@]}" dnd 2>/dev/null | tail -n 1) == "$was" ]] || bad+="dnd-not-restored "
  "${QS[@]}" quietSet $(( ($(date +%-H) + 2) % 24 )) $(( ($(date +%-H) + 3) % 24 )) > /dev/null
  "${QS[@]}" clearNotifs > /dev/null
  if [[ -z $bad ]]; then section smart ok "repeats collapse to x3, history search, quiet hours toggle and restore dnd"; else section smart fail "$bad"; fi
}

check_session() {
  local bad="" ws pid child dir
  hyprctl clients -j | jq -r '.[] | select(.class == "kitty") | .pid' | xargs -r kill; sleep 1
  hyprctl eval 'hl.exec_cmd("[workspace 3 silent] kitty --directory /tmp")' > /dev/null
  for _ in $(seq 50); do hyprctl clients -j | jq -e 'any(.[]; .class == "kitty")' > /dev/null && break; sleep 0.2; done
  sleep 1
  torus-session save
  grep -qP '^kitty\t3\t/tmp$' ~/.local/state/torus/session.tsv || bad+="saved[$(tr '\t' ' ' < ~/.local/state/torus/session.tsv | head -2)] "
  hyprctl clients -j | jq -r '.[] | select(.class == "kitty") | .pid' | xargs -r kill; sleep 1
  torus-session restore
  for _ in $(seq 50); do hyprctl clients -j | jq -e 'any(.[]; .class == "kitty")' > /dev/null && break; sleep 0.2; done
  sleep 1.5
  ws=$(hyprctl clients -j | jq -r '.[] | select(.class == "kitty") | .workspace.id' | head -1)
  pid=$(hyprctl clients -j | jq -r '.[] | select(.class == "kitty") | .pid' | head -1)
  child=$(for k in $(cat /proc/$pid/task/*/children 2>/dev/null); do [[ $(cat /proc/$k/comm) == kitten ]] || echo "$k"; done | head -1)
  dir=$(readlink /proc/$child/cwd 2>/dev/null)
  [[ $ws == 3 ]] || bad+="workspace[$ws] "
  [[ $dir == /tmp ]] || bad+="folder[$dir] "
  [[ ! -e ~/.local/state/torus/session.tsv ]] || bad+="not-consumed "
  hyprctl clients -j | jq -r '.[] | select(.class == "kitty") | .pid' | xargs -r kill
  if [[ -z $bad ]]; then section session ok "kitty saved and restored on workspace 3 in /tmp"; else section session fail "$bad"; fi
}

check_rules() {
  local bad="" r i
  hyprctl eval 'hl.exec_cmd("kitty --class parity.rule")' > /dev/null
  for _ in $(seq 50); do hyprctl clients -j | jq -e 'any(.[]; .class == "parity.rule")' > /dev/null && break; sleep 0.2; done
  [[ $("${QS[@]}" isOpen palette 2>/dev/null | tail -n 1) == true ]] && "${QS[@]}" paletteToggle > /dev/null && sleep 0.5
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:parity.rule" }))' > /dev/null; sleep 0.5
  [[ $(hyprctl activewindow -j | jq -r .class) == parity.rule ]] || bad+="not-focused "
  "${QS[@]}" paletteQuery "rule" > /dev/null; sleep 0.5
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  i=$(tr '|' '\n' <<< "$r" | grep -n 'Window rules: parity.rule' | cut -d: -f1)
  [[ -n $i ]] || bad+="no-rules-entry[$r] "
  if [[ -n $i ]]; then
    "${QS[@]}" paletteRun $((i - 1)) > /dev/null; sleep 0.4
    r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
    [[ $r == rule:Always\ float* ]] || bad+="options[$r] "
    "${QS[@]}" paletteRun 0 > /dev/null; sleep 1
    torus-rules list | grep -qP '^parity\.rule\tfloat' || bad+="not-saved "
  fi
  torus-rules remove parity.rule
  pkill -f "kitty --class [p]arity.rule"
  if [[ -z $bad ]]; then section rules ok "palette rule for the focused window saved"; else section rules fail "$bad"; fi
}

check_calendar() {
  local bad="" ics=$HOME/.cache/parity.ics r st start end
  start=$(date -u -d '+5 min' +%Y%m%dT%H%M00Z); end=$(date -u -d '+35 min' +%Y%m%dT%H%M00Z)
  printf 'BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART:%s\nDTEND:%s\nSUMMARY:Parity sync\nLOCATION:Room 1\nEND:VEVENT\nEND:VCALENDAR\n' "$start" "$end" > "$ics"
  mkdir -p ~/.config/torus; echo "file://$ics" > ~/.config/torus/calendar.url
  local h; h=$(date +%-H); "${QS[@]}" quietSet $(( (h + 2) % 24 )) $(( (h + 3) % 24 )) > /dev/null
  "${QS[@]}" agendaRefresh > /dev/null; sleep 3
  r=$("${QS[@]}" agendaToday 2>/dev/null | tail -n 1)
  [[ $r == *"Parity sync"* ]] || bad+="agenda[$r] "
  for _ in $(seq 40); do st=$("${QS[@]}" islandState 2>/dev/null | tail -n 1); [[ $st == *notification* ]] && break; sleep 1; done
  [[ $st == *notification* ]] || bad+="no-heads-up "
  rm -f ~/.config/torus/calendar.url "$ics" ~/.cache/torus/calendar.tsv
  "${QS[@]}" quietSet $(( ($(date +%-H) + 2) % 24 )) $(( ($(date +%-H) + 3) % 24 )) > /dev/null
  if [[ -z $bad ]]; then section calendar ok "ics feed parsed, agenda shows today, island heads-up before the event"; else section calendar fail "$bad"; fi
}

lock_cycle() {
  hyprctl eval 'hl.exec_cmd("torus-lock")' > /dev/null
  locked_is true || return 1
  sleep "${1:-1}"
  wtype -k Shift_L
  sleep 0.5
  type_pw "$LOCK_PW"
  locked_is false
}

check_spin() {
  local bad="" screens main side a1 a2 b1 b2 kitty
  [[ -n ${LOCK_PW:-} ]] || { section spin fail "LOCK_PW not set"; return; }
  screens=$(hyprctl monitors -j | jq -r '.[].name')
  main=$(head -1 <<<"$screens")
  side=$(sed -n 2p <<<"$screens")
  "${QS[@]}" wallpaper donut > /dev/null
  hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$main\" }))" > /dev/null
  hyprctl eval 'hl.exec_cmd("kitty --class parity-spin")' > /dev/null
  for _ in $(seq 100); do hyprctl clients -j | jq -e 'any(.[]; .class == "parity-spin")' > /dev/null && break; sleep 0.2; done
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:parity-spin" }))' > /dev/null 2>&1
  for _ in $(seq 10); do
    hyprctl clients -j | jq -e 'any(.[]; .class == "parity-spin" and .fullscreen > 0)' > /dev/null && break
    hyprctl eval 'hl.dispatch(hl.dsp.window.fullscreen())' > /dev/null
    sleep 0.5
  done
  lock_cycle || bad+="lock-fullscreen "
  kitty=$(hyprctl clients -j | jq -r '.[] | select(.class == "parity-spin") | .pid')
  [[ -n $kitty ]] && kill "$kitty"
  sleep 1
  lock_cycle 33 || bad+="lock-nap "
  lock_cycle || bad+="lock-3 "
  if [[ -n $side ]]; then
    hyprctl output remove "$side" > /dev/null
    sleep 2
    hyprctl output create headless "$side" > /dev/null
    hyprctl eval "hl.monitor({ output = \"$side\", mode = \"1920x1080\", position = \"1920x0\", scale = 1, transform = 3 })" > /dev/null
    sleep 3
  fi
  a1=$(frames "$main"); b1=$(frames "$side"); sleep 3; a2=$(frames "$main"); b2=$(frames "$side")
  ((a2 > a1)) || bad+="main-stopped($a1=$a2) "
  [[ -z $side ]] || ((b2 > b1)) || bad+="side-stopped($b1=$b2) "
  local detail="main $a1>$a2, side $b1>$b2 after fullscreen lock, 2 locks, screen replug, clock[$("${QS[@]}" donutClock 2>/dev/null)]"
  if [[ -z $bad ]]; then section spin ok "$detail"; else section spin fail "$bad $detail"; fi
}

h=$(date +%-H)
"${QS[@]}" quietSet $(( (h + 2) % 24 )) $(( (h + 3) % 24 )) > /dev/null 2>&1
trap '"${QS[@]}" quietSet 0 6 > /dev/null 2>&1' EXIT

case ${1:-all} in
  media) check_media ;;
  lock) check_lock ;;
  look) check_look ;;
  dashboard) check_dashboard ;;
  donut) check_donut ;;
  spin) check_spin ;;
  night) check_night ;;
  palette) check_palette ;;
  focus) check_focus ;;
  switch) check_switch ;;
  pass) check_pass ;;
  mixer) check_mixer ;;
  shot) check_shot ;;
  panels) check_panels ;;
  pins) check_pins ;;
  smart) check_smart ;;
  session) check_session ;;
  rules) check_rules ;;
  calendar) check_calendar ;;
  notify) check_notify ;;
  island) check_island ;;
  widgets) check_widgets ;;
  groups) check_groups ;;
  clip) check_clip ;;
  ai) check_ai ;;
  polkit) check_polkit ;;
  corners) check_corners ;;
  binds) check_binds ;;
  bar) check_bar ;;
  all) check_binds; check_bar; check_notify; check_island; check_groups; check_clip; check_ai; check_widgets; check_corners; check_donut; check_dashboard; check_look; check_lock; check_spin; check_night; check_palette; check_focus; check_switch; check_pass; check_mixer; check_shot; check_panels; check_pins; check_smart; check_session; check_rules; check_calendar; check_polkit; check_media ;;
  *) echo "unknown section: $1" >&2; exit 1 ;;
esac
echo "parity: $passed/$total"
((passed == total))
