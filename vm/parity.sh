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
awake() { "${QS[@]}" stayAwake true > /dev/null 2>&1 || true; }
section() {
  local name=$1 result=$2 detail=$3
  total=$((total + 1))
  awake
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

BAR_MODULES="cpu memory cpuinfo gpuinfo idle clock workspaces taskbar sunset network audio mic updates privacy servers github containers controller tray clipboard menu notifications power"

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
  for _ in $(seq 50); do [[ $(hyprctl activeworkspace -j 2> /dev/null | jq -r '.id // empty') =~ ^[0-9]+$ ]] && break; sleep 0.2; done
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
  local icons hex; icons=$(sed -n 's/^Theme=//p' ~/.config/kdeglobals)
  [[ $icons == Tela-circle-* && $(gsettings get $g icon-theme) == "'$icons'" ]] || bad+="icons "
  hex=$(jq -r .accent ~/.local/state/torus/theme/qs-colors.json)
  grep -qiE '#(F5E0DC|9670B0)' ~/.config/Kvantum/torus/torus.svg && bad+="kvantum-hyde-accent "
  grep -qi "$hex" ~/.config/Kvantum/torus/torus.svg || bad+="kvantum-no-accent "
  grep -q "theme=torus" ~/.config/Kvantum/kvantum.kvconfig || bad+="kvantum "
  [[ -f ~/.config/Kvantum/torus/torus.svg ]] || bad+="kvantum-theme-missing "
  [[ -d /usr/share/icons/Bibata-Modern-Ice || -d ~/.local/share/icons/Bibata-Modern-Ice ]] || bad+="cursor-theme-missing "
  [[ -d /usr/share/icons/$icons || -d ~/.local/share/icons/$icons ]] || bad+="icon-theme-missing "
  local ff; ff=$(fastfetch --pipe false 2> /dev/null || true); grep -q 'marc' <<< "$ff" && grep -q '@@@@' <<< "$ff" || bad+="fastfetch-donut "
  git config --global --get-all include.path | grep -q torus/delta.gitconfig || bad+="delta "
  systemctl --user is-enabled torus-shell.service > /dev/null 2>&1 || bad+="shell-unit "
  [[ $(systemctl --user is-enabled dunst.service 2>&1) == masked ]] || bad+="dunst-not-masked "
  pacman -Q swaync > /dev/null 2>&1 && bad+="swaync-installed "
  if [[ -z $bad ]]; then section look ok "gtk, qt with the accent in kvantum, cursor, $icons icons, fastfetch donut, delta, shell unit, dunst masked (accent $accent)"; else section look fail "$bad"; fi
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
    local mon c0 c1
    mon=$(hyprctl monitors -j | jq -r '.[0].name')
    grim -o "$mon" /tmp/parity-lock0.png && c0=$(magick /tmp/parity-lock0.png -colorspace Gray -format '%[fx:standard_deviation]' info:)
    type_pw "not-the-password"
    sleep 4
    locked_is true || bad+="wrong-password-unlocked "
    grim -o "$mon" /tmp/parity-lock1.png && c1=$(magick /tmp/parity-lock1.png -colorspace Gray -format '%[fx:standard_deviation]' info:)
    awk -v a="${c0:-0}" -v b="${c1:-0}" 'BEGIN { exit !(b >= a * 0.7) }' || bad+="lock-screen-blank-after-wrong-password($c0>$c1) "
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
  hyprctl eval 'hl.exec_cmd("torus-lock")' > /dev/null
  if locked_is true; then
    type_pw "not-the-password"
    sleep 0.3
    type_pw "$LOCK_PW"
    locked_is false || bad+="password-typed-during-check-lost "
  else
    bad+="retype-lock "
  fi
  hyprctl eval 'hl.exec_cmd("torus-lock")' > /dev/null
  if locked_is true; then
    systemctl --user restart torus-shell.service
    sleep 7
    if pgrep -x hyprlock > /dev/null; then
      type_pw "$LOCK_PW"
      for _ in $(seq 40); do pgrep -x hyprlock > /dev/null || break; sleep 0.25; done
      pgrep -x hyprlock > /dev/null && { bad+="restart-hyprlock-unlock "; unlock; }
      locked_is false || { type_pw "$LOCK_PW"; locked_is false; } || bad+="restart-shell-still-locked "
    elif locked_is true; then
      type_pw "$LOCK_PW"
      locked_is false || bad+="restart-unlock "
    else
      bad+="restart-unlocked-without-password "
    fi
  else
    bad+="restart-lock "
  fi
  hyprctl eval 'hl.exec_cmd("hyprlock")' > /dev/null
  if wait_lock; then
    sleep 1
    "${QS[@]}" lock > /dev/null 2>&1
    sleep 6
    [[ $("${QS[@]}" isLocked 2>/dev/null) == false ]] || bad+="shell-stacked-on-hyprlock "
    pgrep -x hyprlock > /dev/null || bad+="hyprlock-replaced "
    type_pw "$LOCK_PW"
    for _ in $(seq 40); do pgrep -x hyprlock > /dev/null || break; sleep 0.25; done
    pgrep -x hyprlock > /dev/null && { bad+="hyprlock-unlock "; unlock; }
    sleep 2
    [[ -e $XDG_RUNTIME_DIR/torus-lock/locked ]] && bad+="shell-lock-state-left "
    hyprctl eval 'hl.exec_cmd("torus-lock")' > /dev/null
    if locked_is true; then
      type_pw "$LOCK_PW"
      locked_is false || bad+="lock-after-hyprlock "
    else
      bad+="no-lock-after-hyprlock "
    fi
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
  local st
  "${QS[@]}" nightAuto true > /dev/null; sleep 3
  st=$("${QS[@]}" nightState 2>/dev/null | tail -n 1)
  [[ $st == "on auto=true phase=night"* || $st == "off auto=true phase=day"* ]] || bad+="schedule[$st] "
  "${QS[@]}" nightAuto false > /dev/null
  [[ $("${QS[@]}" nightLight 2>/dev/null) == true ]] && "${QS[@]}" nightLightToggle > /dev/null
  if [[ -z $bad ]]; then section night ok "toggles on (5500 K) and stays off, schedule follows the clock [$st]"; else section night fail "$bad"; fi
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
  jq -e 'keys | any(test("^(w|wa|p|pf|pn|ph|f:|rf:|kb:|help:)"))' "${XDG_STATE_HOME:-$HOME/.local/state}/torus/palette-frecency.json" > /dev/null 2>&1 && bad+="remembers-windows-files-or-pass "
  if [[ -z $bad ]]; then section palette ok "calc, apps, actions, kb, emoji, pass hint, closes"; else section palette fail "$bad"; fi
}

pal_wait() {
  local want=$1 i r
  for i in $(seq 25); do
    r=$("${QS[@]}" paletteMode 2>/dev/null | tail -n 1)
    [[ $r == "$want" ]] && return 0
    sleep 0.2
  done
  echo "$r"
  return 1
}

check_palette2() {
  local bad="" r stub=~/.local/bin/pass-cli shot=/tmp/parity-palette.png
  [[ $("${QS[@]}" isOpen palette 2>/dev/null | tail -n 1) == true ]] && "${QS[@]}" paletteToggle > /dev/null && sleep 0.4
  "${QS[@]}" paletteToggle > /dev/null; sleep 0.6
  wtype "kitt"; r=$(pal_wait "all:kitt") || bad+="typed[$r] "
  r=$("${QS[@]}" paletteSections 2>/dev/null | tail -n 1)
  [[ $r == *Apps:* ]] || bad+="sections[$r] "
  wtype -k Tab; r=$(pal_wait "apps:kitt") || bad+="tab-apps[$r] "
  wtype -k Tab; r=$(pal_wait "files:kitt") || bad+="tab-files[$r] "
  wtype -M shift -k Tab -m shift; r=$(pal_wait "apps:kitt") || bad+="backtab-apps[$r] "
  wtype -M shift -k Tab -m shift; r=$(pal_wait "all:kitt") || bad+="backtab-all[$r] "
  wtype -k F1; r=$(pal_wait "kb:") || bad+="f1-help[$r] "
  r=$("${QS[@]}" paletteRows 40 2>/dev/null | tail -n 1)
  [[ $r == "Scopes, Enter jumps there/help:Apps"*help:Proton\ Pass* ]] || bad+="help-rows[$r] "
  wtype -k BackSpace; r=$(pal_wait "all:") || bad+="backspace-all[$r] "
  wtype "2*21"; r=$(pal_wait "all:2*21") || bad+="typed-math[$r] "
  for _ in $(seq 20); do [[ $("${QS[@]}" paletteRows 1 2>/dev/null | tail -n 1) == Calculator/calc:42 ]] && break; sleep 0.2; done
  r=$("${QS[@]}" paletteRows 1 2>/dev/null | tail -n 1)
  [[ $r == Calculator/calc:42 ]] || bad+="math[$r] "
  grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" "$shot" 2> /dev/null
  "${QS[@]}" paletteQuery "#ff8800" > /dev/null; sleep 0.3
  r=$("${QS[@]}" paletteRows 1 2>/dev/null | tail -n 1)
  [[ $r == "color:#ff8800" ]] || bad+="hex[$r] "
  r=$("${QS[@]}" paletteKeys 0 2>/dev/null | tail -n 1)
  [[ $r == "copy hex|copy rgb|copy hsl" ]] || bad+="hex-keys[$r] "
  "${QS[@]}" paletteRunWith 0 ctrl > /dev/null; sleep 0.5
  [[ $(wl-paste -n 2>/dev/null) == "rgb(255, 136, 0)" ]] || bad+="hex-ctrl[$(wl-paste -n 2>/dev/null)] "
  mkdir -p ~/parity-dir/inner
  "${QS[@]}" paletteQuery "~/parity-d" > /dev/null
  for _ in $(seq 20); do [[ $("${QS[@]}" paletteRows 1 2>/dev/null | tail -n 1) == Files/* ]] && break; sleep 0.2; done
  r=$("${QS[@]}" paletteRows 2 2>/dev/null | tail -n 1)
  [[ $r == "Files/folder:parity-dir/"* ]] || bad+="path[$r] "
  "${QS[@]}" paletteRun 0 > /dev/null
  r=$(pal_wait "all:~/parity-dir/") || bad+="path-go-in[$r] "
  for _ in $(seq 20); do [[ $("${QS[@]}" paletteRows 1 2>/dev/null | tail -n 1) == *inner* ]] && break; sleep 0.2; done
  [[ $("${QS[@]}" paletteRows 1 2>/dev/null | tail -n 1) == "Files/folder:inner/" ]] || bad+="path-list[$("${QS[@]}" paletteRows 1 2>/dev/null | tail -n 1)] "
  rm -rf ~/parity-dir
  "${QS[@]}" paletteQuery "github.com/mmrmagno/torus" > /dev/null; sleep 0.3
  r=$("${QS[@]}" paletteRows 1 2>/dev/null | tail -n 1)
  [[ $r == "Open/url:https://github.com/mmrmagno/torus" ]] || bad+="url[$r] "
  "${QS[@]}" paletteQuery "kitty.conf" > /dev/null; sleep 0.3
  [[ $("${QS[@]}" paletteRows 40 2>/dev/null | tail -n 1) != *url:* ]] || bad+="url-false-positive "
  [[ -e $stub && ! -L $stub && $(head -c 40 "$stub") != *parity* ]] && bad+="real-pass-cli "
  printf '#!/usr/bin/env bash\n# parity stub\ncase "$1 $2" in\n  "vault list") echo "- [SID_A==]: Personal" ;;\n  "item list") echo "- [IID_1==]: github.com (state=Active)" ;;\nesac\n' > "$stub"; chmod +x "$stub"
  "${QS[@]}" paletteQuery "p git" > /dev/null
  for _ in $(seq 25); do [[ $("${QS[@]}" paletteResults 2>/dev/null | tail -n 1) == pass:github.com* ]] && break; sleep 0.2; done
  [[ $("${QS[@]}" paletteResults 2>/dev/null | tail -n 1) == pass:github.com* ]] || bad+="pass-scope "
  "${QS[@]}" paletteQuery "github" > /dev/null; sleep 0.3
  [[ $("${QS[@]}" paletteRows 40 2>/dev/null | tail -n 1) != *pass:* ]] || bad+="pass-in-all "
  "${QS[@]}" paletteQuery "" > /dev/null; sleep 0.3
  [[ $("${QS[@]}" paletteRows 40 2>/dev/null | tail -n 1) != *pass:* ]] || bad+="pass-in-empty-state "
  rm -f "$stub"
  "${QS[@]}" paletteQuery "keybind cheat" > /dev/null; sleep 0.3
  r=$("${QS[@]}" paletteRows 1 2>/dev/null | tail -n 1)
  [[ $r == "Actions/action:Keybind cheat sheet" ]] || bad+="action-row[$r] "
  "${QS[@]}" paletteRun 0 > /dev/null; sleep 0.5
  [[ $("${QS[@]}" isOpen cheatsheet 2>/dev/null | tail -n 1) == true ]] && "${QS[@]}" cheatSheetToggle > /dev/null 2>&1
  "${QS[@]}" paletteQuery "" > /dev/null; sleep 0.3
  r=$("${QS[@]}" paletteRows 40 2>/dev/null | tail -n 1)
  [[ $r == *"Frequent/action:Keybind cheat sheet"* ]] || bad+="frecent[$r] "
  "${QS[@]}" paletteToggle > /dev/null; sleep 0.3
  [[ $("${QS[@]}" isOpen palette 2>/dev/null | tail -n 1) == false ]] || bad+="still-open "
  wl-copy --clear
  if [[ -z $bad ]]; then section palette2 ok "sections, Tab scopes, F1 help, math/hex/path/url without prefixes, pass only in its scope, frecent empty state"; else section palette2 fail "$bad"; fi
}

check_projects() {
  local bad="" r d=~/dev/parity-proj
  rm -rf "$d"; mkdir -p "$d"
  git -C "$d" init -q -b parity-branch && git -C "$d" -c user.email=p@example.invalid -c user.name=p commit -q --allow-empty -m init
  git -C "$d" remote add origin git@github.com:someone/parity-proj.git
  echo dirty > "$d/new.txt"
  [[ $("${QS[@]}" isOpen palette 2>/dev/null | tail -n 1) == true ]] && "${QS[@]}" paletteToggle > /dev/null && sleep 0.4
  "${QS[@]}" paletteToggle > /dev/null; sleep 1
  "${QS[@]}" paletteQuery "d parity" > /dev/null; sleep 0.3
  r=$("${QS[@]}" paletteRows 1 2>/dev/null | tail -n 1)
  [[ $r == "project:parity-proj" ]] || bad+="project[$r] "
  r=$("${QS[@]}" paletteSub 0 2>/dev/null | tail -n 1)
  [[ $r == *parity-branch*"1 changed"* ]] || bad+="branch-dirty[$r] "
  r=$("${QS[@]}" paletteKeys 0 2>/dev/null | tail -n 1)
  [[ $r == "terminal|nvim|repo page" ]] || bad+="project-keys[$r] "
  "${QS[@]}" paletteQuery "parity-pro" > /dev/null; sleep 0.3
  [[ $("${QS[@]}" paletteRows 40 2>/dev/null | tail -n 1) == *"Projects/project:parity-proj"* ]] || bad+="project-in-all "
  pkill -x kitty; sleep 0.5
  "${QS[@]}" paletteQuery "d parity" > /dev/null; sleep 0.3
  "${QS[@]}" paletteRun 0 > /dev/null
  for _ in $(seq 40); do hyprctl clients -j | jq -e 'any(.[]; .class == "kitty")' > /dev/null && break; sleep 0.25; done
  sleep 1
  r=$(for p in $(pgrep -x kitty); do for k in $(cat /proc/$p/task/*/children 2> /dev/null); do readlink /proc/$k/cwd; done; done | grep -c parity-proj)
  ((r >= 1)) || bad+="kitty-not-in-project "
  pkill -x kitty
  rm -rf "$d"
  if [[ -z $bad ]]; then section projects ok "d finds a dirty repo with its branch, also in All, Enter opens kitty in it"; else section projects fail "$bad"; fi
}

check_ssh() {
  local bad="" r cfg=~/.ssh/config
  mkdir -p -m 700 ~/.ssh
  [[ -f $cfg ]] && cp "$cfg" /tmp/parity-ssh-config.bak
  printf 'Host parity-host parity-alias\n  HostName parity.example\n  User tester\n  ProxyJump parity-jump\nHost *.wild\n  User x\n' >> "$cfg"
  [[ $("${QS[@]}" isOpen palette 2>/dev/null | tail -n 1) == true ]] && "${QS[@]}" paletteToggle > /dev/null && sleep 0.4
  "${QS[@]}" paletteToggle > /dev/null; sleep 1
  "${QS[@]}" paletteQuery "s parity" > /dev/null; sleep 0.3
  r=$("${QS[@]}" paletteRows 2 2>/dev/null | tail -n 1)
  [[ $r == "ssh:parity-alias|ssh:parity-host" || $r == "ssh:parity-host|ssh:parity-alias" ]] || bad+="hosts[$r] "
  "${QS[@]}" paletteQuery "s parity-host" > /dev/null; sleep 0.3
  r=$("${QS[@]}" paletteSub 0 2>/dev/null | tail -n 1)
  [[ $r == "tester@parity.example  ·  via parity-jump" ]] || bad+="sub[$r] "
  "${QS[@]}" paletteQuery "s wild" > /dev/null; sleep 0.3
  [[ -z $("${QS[@]}" paletteRows 5 2>/dev/null | tail -n 1) ]] || bad+="wildcard-listed "
  "${QS[@]}" paletteQuery "parity-host" > /dev/null; sleep 0.3
  [[ $("${QS[@]}" paletteRows 40 2>/dev/null | tail -n 1) == *"SSH/ssh:parity-host"* ]] || bad+="not-in-all "
  "${QS[@]}" paletteQuery "s parity-host" > /dev/null; sleep 0.3
  "${QS[@]}" paletteRunWith 0 ctrl > /dev/null; sleep 0.5
  [[ $(wl-paste -n 2>/dev/null) == "ssh parity-host" ]] || bad+="copy[$(wl-paste -n 2>/dev/null)] "
  [[ $("${QS[@]}" isOpen palette 2>/dev/null | tail -n 1) == false ]] || { bad+="still-open "; "${QS[@]}" paletteToggle > /dev/null; }
  if [[ -f /tmp/parity-ssh-config.bak ]]; then mv /tmp/parity-ssh-config.bak "$cfg"; else rm -f "$cfg"; fi
  wl-copy --clear
  if [[ -z $bad ]]; then section ssh ok "s lists hosts from ~/.ssh/config (aliases, no wildcards), also in All, Ctrl+Enter copies the command"; else section ssh fail "$bad"; fi
}

check_servers() {
  local bad="" r pid
  (cd /tmp && exec python3 -m http.server 8765 --bind 127.0.0.1 > /dev/null 2>&1) &
  pid=$!
  for _ in $(seq 40); do
    "${QS[@]}" devServersRefresh > /dev/null 2>&1; sleep 0.3
    r=$("${QS[@]}" devServers 2>/dev/null | tail -n 1)
    [[ $r == *8765:python3* ]] && break
  done
  [[ $r == *8765:python3* ]] || bad+="not-listed[$r] "
  [[ $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8765/) == 200 ]] || bad+="server-not-up "
  r=$("${QS[@]}" devServerStop 8765 2>/dev/null | tail -n 1)
  [[ $r == "stopping $pid" ]] || bad+="stop[$r] "
  for _ in $(seq 25); do kill -0 "$pid" 2> /dev/null || break; sleep 0.2; done
  kill -0 "$pid" 2> /dev/null && { bad+="still-running "; kill "$pid"; }
  for _ in $(seq 20); do
    "${QS[@]}" devServersRefresh > /dev/null 2>&1; sleep 0.3
    [[ $("${QS[@]}" devServers 2>/dev/null | tail -n 1) != *8765* ]] && break
  done
  [[ $("${QS[@]}" devServers 2>/dev/null | tail -n 1) != *8765* ]] || bad+="still-listed "
  [[ $("${QS[@]}" devServerStop 1 2>/dev/null | tail -n 1) == none ]] || bad+="stops-unknown-port "
  if [[ -z $bad ]]; then section servers ok "a python http.server shows up in the chip with its port, stop ends it"; else section servers fail "$bad"; fi
}

check_cmddone() {
  local bad="" r
  hyprctl eval 'hl.exec_cmd("kitty --class parity.cmd")' > /dev/null
  for _ in $(seq 50); do hyprctl clients -j | jq -e 'any(.[]; .class == "parity.cmd")' > /dev/null && break; sleep 0.2; done
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:parity.cmd" }))' > /dev/null; sleep 2
  wtype "sleep 31"; wtype -k Return; sleep 1
  hyprctl eval 'hl.exec_cmd("kitty --class parity.other")' > /dev/null
  for _ in $(seq 50); do hyprctl clients -j | jq -e 'any(.[]; .class == "parity.other")' > /dev/null && break; sleep 0.2; done
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:parity.other" }))' > /dev/null
  sleep 34
  "${QS[@]}" paletteToggle > /dev/null; sleep 0.5
  "${QS[@]}" paletteQuery "n sleep 31" > /dev/null; sleep 0.3
  r=$("${QS[@]}" paletteSub 0 2>/dev/null | tr '\n' ' ')
  [[ $r == *"sleep 31 finished with status: 0"* ]] || bad+="no-notification[${r: -120}] "
  "${QS[@]}" paletteToggle > /dev/null
  pkill -f "kitty --class parity.(cmd|other)"
  if [[ -z $bad ]]; then section cmddone ok "kitty reports a 31 s command that finished while unfocused"; else section cmddone fail "$bad"; fi
}

check_trust() {
  local bad="" r crashes=${XDG_CACHE_HOME:-$HOME/.cache}/torus/crashes
  [[ -n ${LOCK_PW:-} ]] || { section trust fail "LOCK_PW not set"; return; }
  rm -rf "$crashes"
  hyprctl eval 'hl.exec_cmd("torus-lock")' > /dev/null
  if locked_is true; then
    systemctl --user stop torus-shell.service
    sleep 2
    pgrep -x hyprlock > /dev/null && bad+="hyprlock-on-clean-stop "
    r=$(~/.local/bin/torus-doctor 2>&1)
    grep -q 'purple screen' <<< "$r" || bad+="doctor-missed-purple "
    local since; since=$(date '+%F %T')
    r=$(~/.local/bin/torus-doctor --fix 2>&1)
    grep -q 'holds the lock again' <<< "$r" || bad+="fix[$(grep lock <<< "$r" | tr -s ' ' | tr '\n' ';')] "
    locked_is true || bad+="not-locked-after-fix "
    pgrep -x hyprlock > /dev/null && { bad+="hyprlock-took-over "; pkill -USR1 -x hyprlock; }
    journalctl --user -u torus-shell --since "$since" --no-pager -o cat | grep -q 'not confirmed after' && bad+="relock-not-confirmed "
    [[ $(journalctl --user -u torus-shell --since "$since" --no-pager -o cat | grep -c 'Started torus shell') -le 1 ]] || bad+="restarted-twice "
    sleep 2
    type_pw "$LOCK_PW"
    locked_is false || bad+="unlock-after-fix "
  else
    bad+="no-lock "
  fi
  [[ -z $(ls "$crashes"/*.log 2> /dev/null) ]] || bad+="clean-stop-saved-a-crash "
  "${QS[@]}" clearNotifs > /dev/null 2>&1
  systemctl --user kill -s KILL torus-shell.service
  for _ in $(seq 60); do [[ $("${QS[@]}" isLocked 2> /dev/null) == false ]] && break; sleep 0.5; done
  [[ -n $(ls "$crashes"/*.log 2> /dev/null) ]] || bad+="no-crash-log "
  grep -q 'result: signal' "$crashes"/*.log 2> /dev/null || bad+="crash-result "
  for _ in $(seq 30); do [[ $("${QS[@]}" notifGroups 2> /dev/null) == *torus:* ]] && break; sleep 0.5; done
  [[ $("${QS[@]}" notifGroups 2> /dev/null) == *torus:* ]] || bad+="no-crash-notification "
  [[ -e $crashes/pending ]] && bad+="pending-left "
  grep -q '1 shell crash' <<< "$(~/.local/bin/torus-doctor 2>&1)" || bad+="doctor-no-crash-note "
  pkill -f 'notify-send -a torus -i dialog-warning' 2> /dev/null
  "${QS[@]}" clearNotifs > /dev/null 2>&1
  rm -rf "$crashes"
  if [[ -z $bad ]]; then section trust ok "doctor --fix relocks a lock nobody draws, a killed shell leaves a log and says so"; else section trust fail "$bad"; fi
}

check_github() {
  local bad="" r stub=/usr/local/bin/gh
  sudo tee "$stub" > /dev/null <<'S'
#!/bin/sh
[ "$1" = auth ] && exit 0
cat <<'J'
{"data":{"viewer":{"login":"parity","pullRequests":{"nodes":[{"number":7,"title":"parity pr","url":"https://github.com/parity/a/pull/7","isDraft":false,"updatedAt":"2026-11-11T10:00:00Z","repository":{"nameWithOwner":"parity/a"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS"}}}]}}]},
"repositories":{"nodes":[{"nameWithOwner":"parity/b","url":"https://github.com/parity/b","isArchived":false,"pushedAt":"2026-11-11T10:00:00Z","defaultBranchRef":{"name":"main","target":{"statusCheckRollup":{"state":"FAILURE"}}}}]}},
"review":{"nodes":[{"number":3,"title":"parity review","url":"https://github.com/o/c/pull/3","updatedAt":"2026-11-11T08:00:00Z","author":{"login":"pal"},"repository":{"nameWithOwner":"o/c"}}]}}}
J
S
  sudo chmod 755 "$stub"
  for _ in $(seq 20); do
    "${QS[@]}" githubRefresh > /dev/null 2>&1; sleep 0.5
    r=$("${QS[@]}" githubState 2> /dev/null | tail -n 1)
    [[ $r == ok:* ]] && break
  done
  [[ $r == ok:1:1:1:2 ]] || bad+="state[$r] "
  sleep 1
  r=$("${QS[@]}" modules 2> /dev/null | tail -n 1)
  [[ $r == *github* ]] || bad+="no-chip "
  [[ $("${QS[@]}" isOpen palette 2>/dev/null | tail -n 1) == true ]] && "${QS[@]}" paletteToggle > /dev/null && sleep 0.4
  "${QS[@]}" paletteToggle > /dev/null; sleep 1
  "${QS[@]}" paletteQuery "gh " > /dev/null; sleep 0.5
  r=$("${QS[@]}" paletteSections 2> /dev/null | tail -n 1)
  [[ $r == "Review requests:1|Failing:1|My pull requests:1" ]] || bad+="sections[$r] "
  "${QS[@]}" paletteQuery "gh failing" > /dev/null; sleep 0.5
  r=$("${QS[@]}" paletteRows 3 2> /dev/null | tail -n 1)
  [[ $r == "Failing/github:parity/b" ]] || bad+="search[$r] "
  "${QS[@]}" paletteToggle > /dev/null
  sudo rm -f "$stub"
  if [[ -z $bad ]]; then section github ok "review requests, failing main and my PRs in the chip and under gh in the palette"; else section github fail "$bad"; fi
}

check_scratch() {
  local bad="" r d=/tmp/parity-proj
  rm -rf "$d"; mkdir -p "$d/sub"; git init -q "$d"
  hyprctl eval "hl.exec_cmd(\"kitty --class parity.proj --directory $d/sub\")" > /dev/null
  for _ in $(seq 50); do hyprctl clients -j | jq -e 'any(.[]; .class == "parity.proj")' > /dev/null && break; sleep 0.2; done
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:parity.proj" }))' > /dev/null; sleep 1
  ~/.local/bin/torus-dropdown --project
  for _ in $(seq 50); do hyprctl clients -j | jq -e 'any(.[]; .class == "torus-dropdown-parity-proj")' > /dev/null && break; sleep 0.2; done
  r=$(hyprctl clients -j | jq -r '.[] | select(.class == "torus-dropdown-parity-proj") | "\(.workspace.name):\(.floating)"')
  [[ $r == "special:sc-parity-proj:true" ]] || bad+="spawn[$r] "
  sleep 1
  r=$(hyprctl monitors -j | jq -r '[.[].specialWorkspace.name] | join(",")')
  [[ $r == *special:sc-parity-proj* ]] || bad+="not-shown[$r] "
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:torus-dropdown-parity-proj" }))' > /dev/null; sleep 0.5
  [[ $(hyprctl activewindow -j | jq -r .class) == torus-dropdown-parity-proj ]] || bad+="not-focused "
  ~/.local/bin/torus-dropdown --project; sleep 1
  r=$(hyprctl monitors -j | jq -r '[.[].specialWorkspace.name] | join(",")')
  [[ $r != *sc-parity-proj* ]] || bad+="not-hidden[$r] "
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:parity.proj" }))' > /dev/null; sleep 0.5
  ~/.local/bin/torus-dropdown --project; sleep 1
  [[ $(hyprctl clients -j | jq '[.[] | select(.class == "torus-dropdown-parity-proj")] | length') == 1 ]] || bad+="respawned "
  ~/.local/bin/torus-dropdown --project 2> /dev/null; sleep 0.5
  hyprctl monitors -j | jq -e 'any(.[]; .specialWorkspace.name == "special:sc-parity-proj")' > /dev/null && hyprctl eval 'hl.dispatch(hl.dsp.workspace.toggle_special("sc-parity-proj"))' > /dev/null
  hyprctl eval 'hl.dispatch(hl.dsp.window.close({ window = "class:torus-dropdown-parity-proj" }))' > /dev/null 2>&1
  hyprctl eval 'hl.dispatch(hl.dsp.window.close({ window = "class:parity.proj" }))' > /dev/null 2>&1
  sleep 0.5
  pkill -f 'kitty --class (torus-dropdown-parity-proj|parity.proj)' 2> /dev/null
  rm -rf "$d"
  if [[ -z $bad ]]; then section scratch ok "SUPER+\` opens a floating terminal in the git root of the focused window, hides it, reuses it"; else section scratch fail "$bad"; fi
}

pw_node_id() {
  pw-cli ls Node | grep -B5 "node.name = \"$1\"" | sed -n 's/^\s*id \([0-9]*\),.*/\1/p' | head -1
}
pw_drop() {
  local id; id=$(pw_node_id "$1"); [[ -n $id ]] && pw-cli destroy "$id" > /dev/null 2>&1
  return 0
}
meeting_is() {
  local want=$1 tries=${2:-60}
  for _ in $(seq "$tries"); do [[ $("${QS[@]}" meetingState 2> /dev/null) == "$want"* ]] && return 0; sleep 0.5; done
  return 1
}

check_meeting() {
  local bad="" pid
  "${QS[@]}" meetingAuto true > /dev/null
  pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=parity-mic media.class=Audio/Source/Virtual audio.position=[FL FR] object.linger=true }' > /dev/null
  sleep 1
  pw-record --target parity-mic /dev/null < /dev/null > /dev/null 2>&1 &
  pid=$!
  sleep 12
  [[ $("${QS[@]}" meetingState) == "idle auto=true mic=true cam=false dnd=false" ]] || bad+="mic-alone[$("${QS[@]}" meetingState)] "
  pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=parity-cam media.class=Stream/Input/Video object.linger=true }' > /dev/null
  meeting_is "active" 30 || bad+="no-meeting[$("${QS[@]}" meetingState)] "
  [[ $("${QS[@]}" dnd) == true ]] || bad+="dnd-not-on "
  pw_drop parity-cam
  meeting_is "idle" 60 || bad+="never-ended "
  [[ $("${QS[@]}" dnd) == false ]] || bad+="dnd-not-restored "
  "${QS[@]}" setDnd true > /dev/null
  pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=parity-cam media.class=Stream/Input/Video object.linger=true }' > /dev/null
  meeting_is "active" 30 || bad+="no-second-meeting "
  "${QS[@]}" setDnd false > /dev/null
  pw_drop parity-cam
  meeting_is "idle" 60 || bad+="second-never-ended "
  [[ $("${QS[@]}" dnd) == false ]] || bad+="my-dnd-change-overridden "
  "${QS[@]}" meetingAuto false > /dev/null
  pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=parity-cam media.class=Stream/Input/Video object.linger=true }' > /dev/null
  sleep 12
  [[ $("${QS[@]}" meetingState) == idle* ]] || bad+="auto-off-ignored "
  "${QS[@]}" meetingAuto true > /dev/null
  pw_drop parity-cam; kill "$pid" 2> /dev/null; pw_drop parity-mic
  "${QS[@]}" meetingNow true > /dev/null
  meeting_is "active" 4 || bad+="manual-start "
  [[ $("${QS[@]}" dnd) == true ]] || bad+="manual-no-dnd "
  sleep 25
  meeting_is "active" 2 || bad+="manual-ended-by-itself "
  "${QS[@]}" meetingNow false > /dev/null
  meeting_is "idle" 4 || bad+="manual-end "
  [[ $("${QS[@]}" dnd) == false ]] || bad+="manual-dnd-left-on "
  if [[ -z $bad ]]; then section meeting ok "mic plus camera holds notifications, mic alone does not, DND restored, off switch, manual start and end"; else section meeting fail "$bad"; fi
}

check_overlay() {
  local bad="" conf=~/.local/state/torus/mangohud.conf r
  command -v mangohud > /dev/null || { section overlay fail "mangohud not installed in the VM"; return; }
  ~/.local/bin/torus-mangohud off > /dev/null
  grep -q '^no_display' "$conf" || bad+="off-still-shows "
  grep -qi "gpu_color=$(jq -r .accent ~/.local/state/torus/theme/qs-colors.json | tr -d '#')" "$conf" || bad+="no-accent "
  "${QS[@]}" overlayToggle > /dev/null; sleep 1
  r=$("${QS[@]}" overlayState 2> /dev/null)
  [[ $r == "on installed=true" ]] || bad+="state[$r] "
  grep -q '^no_display' "$conf" && bad+="on-still-hidden "
  [[ $("${QS[@]}" islandState) == state:osd* ]] || bad+="no-island "
  "${QS[@]}" overlayToggle > /dev/null; sleep 1
  grep -q '^no_display' "$conf" || bad+="toggle-off "
  [[ $(env -i HOME="$HOME" sh -c '. ~/.config/uwsm/env; echo "$MANGOHUD:$MANGOHUD_CONFIGFILE"') == "1:$conf" ]] || bad+="session-env "
  if [[ -z $bad ]]; then section overlay ok "MangoHud config follows the accent, palette toggles it live, session env set"; else section overlay fail "$bad"; fi
}

check_containers() {
  local bad="" r
  command -v podman > /dev/null || { section containers fail "podman missing in the VM"; return; }
  podman rm -f parity-box > /dev/null 2>&1
  timeout 120 podman run -d --name parity-box docker.io/library/busybox:1.37 sleep 100000 > /dev/null 2>&1 || bad+="fixture "
  for _ in $(seq 20); do r=$("${QS[@]}" containers 2> /dev/null); [[ $r == *podman:parity-box* ]] && break; sleep 1; done
  [[ $r == *podman:parity-box* ]] || bad+="not-listed[$r] "
  [[ $("${QS[@]}" isOpen palette 2>/dev/null | tail -n 1) == true ]] && "${QS[@]}" paletteToggle > /dev/null && sleep 0.4
  "${QS[@]}" paletteToggle > /dev/null; sleep 1
  "${QS[@]}" paletteQuery "c parity-box" > /dev/null; sleep 0.5
  r=$("${QS[@]}" paletteRows 1 2> /dev/null)
  [[ $r == "container:parity-box" ]] || bad+="palette[$r] "
  [[ $("${QS[@]}" paletteKeys 0 2> /dev/null) == "logs|restart|stop" ]] || bad+="keys "
  "${QS[@]}" paletteToggle > /dev/null
  r=$("${QS[@]}" containerAct parity-box stop 2> /dev/null)
  [[ $r == "stop podman:"* ]] || bad+="stop[$r] "
  for _ in $(seq 30); do [[ -z $(podman ps -q -f name=parity-box) ]] && break; sleep 1; done
  [[ -z $(podman ps -q -f name=parity-box) ]] || bad+="still-running "
  for _ in $(seq 20); do r=$("${QS[@]}" containers 2> /dev/null); [[ $r != *parity-box* ]] && break; sleep 1; done
  [[ $r != *parity-box* ]] || bad+="still-listed "
  podman rm -f parity-box > /dev/null 2>&1
  if [[ -z $bad ]]; then section containers ok "podman container in the dev pill and under c in the palette, stop works"; else section containers fail "$bad"; fi
}

check_games() {
  local bad="" S=~/.local/share/Steam
  [[ -n $(~/.local/bin/torus-games) ]] || { section games fail "no fake Steam library in the VM"; return; }
  [[ $("${QS[@]}" isOpen games) == true ]] && "${QS[@]}" gamesToggle > /dev/null && sleep 0.5
  rm -f /tmp/parity-xdg-open
  mkdir -p ~/.local/share/applications
  printf '#!/bin/sh\necho "$1" > /tmp/parity-xdg-open\n' > /tmp/parity-steam; chmod +x /tmp/parity-steam
  printf '[Desktop Entry]\nType=Application\nName=parity steam\nExec=/tmp/parity-steam %%u\nMimeType=x-scheme-handler/steam;\n' > ~/.local/share/applications/parity-steam.desktop
  xdg-mime default parity-steam.desktop x-scheme-handler/steam
  "${QS[@]}" gamesToggle > /dev/null; sleep 1.5
  [[ $("${QS[@]}" isOpen games) == true ]] || bad+="not-open "
  wtype "portal"; sleep 0.5; wtype -k Return; sleep 2
  [[ $("${QS[@]}" isOpen games) == false ]] || bad+="still-open "
  [[ $(cat /tmp/parity-xdg-open 2> /dev/null) == steam://rungameid/620 ]] || bad+="launch[$(cat /tmp/parity-xdg-open 2> /dev/null)] "
  rm -f ~/.local/share/applications/parity-steam.desktop
  [[ -n $bad ]] && { timeout 10 grim -o Virtual-1 /tmp/parity-fail-games.png; journalctl --user -u torus-shell --since "-60s" -o cat > /tmp/parity-fail-games.log; hyprctl layers -j > /tmp/parity-fail-games.layers; hyprctl activewindow -j > /tmp/parity-fail-games.active; }
  if [[ -z $bad ]]; then section games ok "game hub opens, filters by typing, Enter launches the Steam URL and closes"; else section games fail "$bad"; fi
}

check_threads() {
  local bad="" r
  "${QS[@]}" clearNotifs > /dev/null 2>&1; sleep 0.5
  for b in "hi there" "how are you?" "lunch at 12?"; do notify-send -a ParityChat "Anna" "$b"; sleep 0.3; done
  notify-send -a ParityChat "Ben" "yo"; sleep 1
  r=$("${QS[@]}" notifThreads 2> /dev/null)
  [[ $r == *"ParityChat:Ben=1,Anna=3"* ]] || bad+="threads[$r] "
  [[ $("${QS[@]}" notifCount) == 4 ]] || bad+="count "
  "${QS[@]}" clearNotifs > /dev/null 2>&1
  if [[ -z $bad ]]; then section threads ok "chat messages from one sender fold into one card, newest first"; else section threads fail "$bad"; fi
}

check_displays() {
  local bad="" p
  pos() { hyprctl monitors -j | jq -r '.[] | select(.name=="SIDE") | "\(.x)x\(.y)"'; }
  rule() { hyprctl eval "hl.monitor({ output = \"SIDE\", mode = \"1920x1080\", position = \"$1\", scale = 1, transform = 3 })" > /dev/null; sleep 1; }
  hyprctl monitors -j | jq -e 'any(.[]; .name == "SIDE")' > /dev/null || { section displays fail "no SIDE output"; return; }
  rule 3000x500
  ~/.local/bin/torus-displays save > /dev/null
  rule 1280x0
  hyprctl output remove SIDE > /dev/null; sleep 2
  hyprctl output create headless SIDE > /dev/null
  for _ in $(seq 20); do p=$(pos); [[ $p == 3000x500 ]] && break; sleep 0.5; done
  [[ $p == 3000x500 ]] || bad+="not-restored[$p] "
  ~/.local/bin/torus-displays forget > /dev/null
  rule 1280x0
  [[ $(pos) == 1280x0 ]] || bad+="reset "
  if [[ -z $bad ]]; then section displays ok "a saved layout comes back when the screen is plugged in again"; else section displays fail "$bad"; fi
}

check_face() {
  local bad=""
  [[ -n ${LOCK_PW:-} ]] || { section face fail "LOCK_PW not set"; return; }
  printf '#!/bin/sh\n[ -e /tmp/face-ok ] && exit 0\nsleep 2\nexit 1\n' | sudo tee /usr/local/bin/fake-face > /dev/null
  sudo chmod 755 /usr/local/bin/fake-face
  printf 'auth sufficient pam_exec.so quiet /usr/local/bin/fake-face\nauth required pam_deny.so\naccount required pam_unix.so\n' | sudo tee /etc/pam.d/torus-face > /dev/null
  touch /tmp/face-ok
  hyprctl eval 'hl.exec_cmd("torus-lock")' > /dev/null
  locked_is true || bad+="no-lock "
  locked_is false || bad+="face-did-not-unlock "
  rm -f /tmp/face-ok
  hyprctl eval 'hl.exec_cmd("torus-lock")' > /dev/null
  locked_is true || bad+="no-second-lock "
  sleep 4
  [[ $("${QS[@]}" isLocked) == true ]] || bad+="unknown-face-unlocked "
  type_pw "$LOCK_PW"
  locked_is false || bad+="password-after-missed-face "
  sudo rm -f /etc/pam.d/torus-face /usr/local/bin/fake-face
  [[ -n $bad ]] && journalctl --user -u torus-shell --since "-90s" -o cat > /tmp/parity-fail-face.log
  if [[ -z $bad ]]; then section face ok "a recognized face unlocks, an unknown one does not, the password always works"; else section face fail "$bad"; fi
}

check_reload() {
  local bad="" ok0 fail0
  c() { journalctl --user -u torus-shell --no-pager -o cat | grep -c "$1"; }
  ok0=$(c "Configuration Loaded"); fail0=$(c "Failed to load configuration")
  "${QS[@]}" reload > /dev/null 2>&1
  sleep 5
  (($(c "Configuration Loaded") > ok0)) || bad+="no-reload "
  (($(c "Failed to load configuration") > fail0)) && bad+="reload-failed "
  [[ $("${QS[@]}" isLocked 2> /dev/null) == false ]] || bad+="shell-gone "
  if [[ -z $bad ]]; then section reload ok "a live reload (what install.sh does) loads the config without errors"; else section reload fail "$bad"; fi
}

check_follow() {
  local bad="" r
  focus() { hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$1\" }))" > /dev/null; }
  focus Virtual-1; sleep 0.6
  "${QS[@]}" dashboardToggle > /dev/null; sleep 1
  focus SIDE; sleep 1
  r=$("${QS[@]}" panelScreen dashboard)
  [[ $r == Virtual-1 ]] || bad+="dashboard-moved[$r] "
  "${QS[@]}" dashboardToggle > /dev/null; sleep 0.6
  focus Virtual-1; sleep 0.6
  "${QS[@]}" centerToggle > /dev/null; sleep 1
  focus SIDE; sleep 0.15; focus Virtual-1; sleep 1
  r=$("${QS[@]}" panelScreen center)
  [[ $r == Virtual-1 ]] || bad+="center-jumped-on-a-pass[$r] "
  focus SIDE; sleep 1.2
  r=$("${QS[@]}" panelScreen center)
  [[ $r == SIDE ]] || bad+="center-did-not-follow[$r] "
  "${QS[@]}" centerToggle > /dev/null; sleep 0.5
  focus Virtual-1
  if [[ -z $bad ]]; then section follow ok "dashboard stays put, a quick pass to the other screen moves nothing, a real move takes panels along"; else section follow fail "$bad"; fi
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
  "${QS[@]}" altTab next > /dev/null; "${QS[@]}" altTab apply > /dev/null; sleep 0.4
  [[ $(hyprctl activewindow -j | jq -r .address) == "$before" ]] || bad+="second-tap-not-back "
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
  "${QS[@]}" themeToggle > /dev/null; sleep 1.5
  [[ $("${QS[@]}" isOpen theme 2>/dev/null | tail -n 1) == true ]] || bad+="theme-closed "
  "${QS[@]}" themeToggle > /dev/null; sleep 0.5
  [[ $("${QS[@]}" isOpen theme 2>/dev/null | tail -n 1) == false ]] || bad+="theme-stuck "
  if [[ -z $bad ]]; then section panels ok "network panel sees the wired link, update centre lists updates and arch news [$r], theme studio opens"; else section panels fail "$bad"; fi
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
  rm -f ~/.local/state/torus/session.restored-in
  torus-session restore
  for _ in $(seq 50); do hyprctl clients -j | jq -e 'any(.[]; .class == "kitty")' > /dev/null && break; sleep 0.2; done
  sleep 1.5
  ws=$(hyprctl clients -j | jq -r '.[] | select(.class == "kitty") | .workspace.id' | head -1)
  pid=$(hyprctl clients -j | jq -r '.[] | select(.class == "kitty") | .pid' | head -1)
  child=$(for k in $(cat /proc/$pid/task/*/children 2>/dev/null); do [[ $(cat /proc/$k/comm) == kitten ]] || echo "$k"; done | head -1)
  dir=$(readlink /proc/$child/cwd 2>/dev/null)
  [[ $ws == 3 ]] || bad+="workspace[$ws] "
  [[ $dir == /tmp ]] || bad+="folder[$dir] "
  [[ -s ~/.local/state/torus/session.tsv ]] || bad+="save-consumed "
  torus-session restore; sleep 2.5; hyprctl clients -j | jq -e '[.[] | select(.class == "kitty")] | length == 1' > /dev/null || bad+="restored-twice "
  "${QS[@]}" sessionToggle > /dev/null; sleep 1.5
  [[ $("${QS[@]}" isOpen session 2>/dev/null | tail -n 1) == true ]] || bad+="panel-closed "
  local st
  st=$("${QS[@]}" sessionState 2>/dev/null | tail -n 1)
  [[ $st == "on keep="[1-9]* ]] || bad+="panel-state[$st] "
  torus-session off; "${QS[@]}" sessionToggle > /dev/null; sleep 0.5; "${QS[@]}" sessionToggle > /dev/null; sleep 1.5
  [[ $("${QS[@]}" sessionState 2>/dev/null | tail -n 1) == off* ]] || bad+="panel-not-off "
  torus-session on; "${QS[@]}" sessionToggle > /dev/null
  hyprctl clients -j | jq -r '.[] | select(.class == "kitty") | .pid' | xargs -r kill
  if [[ -z $bad ]]; then section session ok "kitty saved and restored on workspace 3 in /tmp, panel shows on/off and what comes back"; else section session fail "$bad"; fi
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
  i=$(tr '|' '\n' <<< "$r" | grep -n 'Window: parity.rule' | cut -d: -f1)
  [[ -n $i ]] || bad+="no-window-entry[$r] "
  if [[ -n $i ]]; then
    "${QS[@]}" paletteRun $((i - 1)) > /dev/null; sleep 0.4
    "${QS[@]}" paletteQuery "rule rules for" > /dev/null; sleep 0.4
    r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
    i=$(tr '|' '\n' <<< "$r" | grep -n 'Rules for parity.rule' | cut -d: -f1)
    [[ -n $i ]] || bad+="no-rules-entry[$r] "
  fi
  if [[ -n $i ]]; then
    "${QS[@]}" paletteRun $((i - 1)) > /dev/null; sleep 0.4
    r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
    [[ $r == rule:Always\ float* ]] || bad+="options[$r] "
    "${QS[@]}" paletteRun 0 > /dev/null; sleep 1
    torus-rules list | grep -qP '^parity\.rule\tfloat' || bad+="not-saved "
  fi
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:parity.rule" }))' > /dev/null; sleep 0.5
  "${QS[@]}" paletteQuery "window" > /dev/null; sleep 0.5
  "${QS[@]}" paletteRun 0 > /dev/null; sleep 0.4
  "${QS[@]}" paletteQuery "window 7" > /dev/null; sleep 0.4
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  [[ $r == "action:Move to workspace 7" ]] || bad+="move-entry[$r] "
  "${QS[@]}" paletteRun 0 > /dev/null; sleep 1
  [[ $(hyprctl clients -j | jq -r '.[] | select(.class == "parity.rule") | .workspace.id') == 7 ]] || bad+="not-moved "
  torus-rules remove parity.rule
  pkill -f "kitty --class [p]arity.rule"
  if [[ -z $bad ]]; then section rules ok "palette window menu: rule saved, moved to workspace 7"; else section rules fail "$bad"; fi
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

check_qmllog() {
  local inv out
  inv=$(systemctl --user show -p InvocationID --value torus-shell)
  out=$(journalctl --user -u torus-shell "_SYSTEMD_INVOCATION_ID=$inv" --no-pager -o cat 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' \
    | grep -E 'WARN qml|ERROR|TypeError|ReferenceError|[Bb]inding loop|Unable to assign|unavailable|is not a function|Cannot read property' \
    | grep -vE 'dmabuf: Failed to find render device|quickshell\.dbus' | sort -u | head -5)
  if [[ -z $out ]]; then section qmllog ok "no QML warnings since the shell started"; else section qmllog fail "$(tr '\n' '|' <<<"$out" | cut -c1-600)"; fi
}

awake
case ${1:-all} in
  media) check_media ;;
  lock) check_lock ;;
  look) check_look ;;
  dashboard) check_dashboard ;;
  donut) check_donut ;;
  spin) check_spin ;;
  night) check_night ;;
  palette) check_palette ;;
  palette2) check_palette2 ;;
  projects) check_projects ;;
  ssh) check_ssh ;;
  servers) check_servers ;;
  cmddone) check_cmddone ;;
  trust) check_trust ;;
  github) check_github ;;
  scratch) check_scratch ;;
  meeting) check_meeting ;;
  overlay) check_overlay ;;
  containers) check_containers ;;
  games) check_games ;;
  threads) check_threads ;;
  displays) check_displays ;;
  face) check_face ;;
  reload) check_reload ;;
  follow) check_follow ;;
  focus) check_focus ;;
  switch) check_switch ;;
  pass) check_pass ;;
  mixer) check_mixer ;;
  shot) check_shot ;;
  panels) check_panels ;;
  pins) check_pins ;;
  smart) check_smart ;;
  session) check_session ;;
  qmllog) check_qmllog ;;
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
  all) check_binds; check_bar; check_notify; check_island; check_groups; check_clip; check_ai; check_widgets; check_corners; check_donut; check_dashboard; check_look; check_lock; check_spin; check_night; check_palette; check_palette2; check_projects; check_ssh; check_servers; check_cmddone; check_trust; check_github; check_scratch; check_meeting; check_overlay; check_containers; check_games; check_threads; check_displays; check_face; check_reload; check_follow; check_focus; check_switch; check_pass; check_mixer; check_shot; check_panels; check_pins; check_smart; check_session; check_rules; check_calendar; check_polkit; check_media; check_qmllog ;;
  *) echo "unknown section: $1" >&2; exit 1 ;;
esac
echo "parity: $passed/$total"
((passed == total))
