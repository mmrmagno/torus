#!/usr/bin/env bash
set -uo pipefail

[[ $(cat /etc/hostname 2> /dev/null) == torus-vm ]] || { echo "vm/parity.sh wipes the clipboard, clips and Steam logs it tests with: it only runs inside the torus VM" >&2; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
export LANG=${LANG:-C.UTF-8}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)
export HYPRLAND_INSTANCE_SIGNATURE
QS=(qs -c torus ipc call torus)
. "$REPO/home/.local/share/torus/checks.sh"

passed=0 total=0
section_t0=$(date +%s)
awake() {
  "${QS[@]}" stayAwake true > /dev/null 2>&1 || true
  local h; h=$(date +%-H)
  [[ $("${QS[@]}" quietSet $(( (h + 2) % 24 )) $(( (h + 3) % 24 )) 2> /dev/null | tail -n 1) == false ]] && "${QS[@]}" setDnd false > /dev/null 2>&1
  true
}
section() {
  local name=$1 result=$2 detail=$3
  total=$((total + 1))
  awake
  local took=$(($(date +%s) - section_t0))
  if [[ $result == ok ]]; then
    passed=$((passed + 1))
    echo "$name: ok $detail [${took}s]"
  else
    echo "$name: FAIL $detail [${took}s]"
  fi
  section_t0=$(date +%s)
}

check_binds() {
  local missing errors
  missing=$(comm -23 <(sort -u "$REPO/tests/binds.expected") <(torus_bind_list))
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

BAR_MODULES="cpu memory cpuinfo gpuinfo idle clock workspaces taskbar sunset network audio mic updates privacy servers github homelab containers controller tray clipboard menu notifications power"

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
  "${QS[@]}" recallForget > /dev/null 2>&1
  export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
  magick -size 64x40 xc:'#cba6f7' "$img"
  wl-copy --type image/png < "$img"; sleep 0.6
  printf 'parity clip %s' "$$" | wl-copy; sleep 0.6
  rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/torus/clip"
  "${QS[@]}" clipToggle > /dev/null 2>&1; sleep 2
  n=$("${QS[@]}" clipCount 2>/dev/null | tail -n 1)
  ((n >= 2)) || bad+="count:[$n] "
  ls "${XDG_CACHE_HOME:-$HOME/.cache}"/torus/clip/*.img > /dev/null 2>&1 || bad+="no-thumbnail "
  rm -f "${XDG_CACHE_HOME:-$HOME/.cache}"/torus/clip/*.img
  "${QS[@]}" clipToggle > /dev/null 2>&1; sleep 0.5; "${QS[@]}" clipToggle > /dev/null 2>&1; sleep 0.5
  "${QS[@]}" clipToggle > /dev/null 2>&1; sleep 2
  ls "${XDG_CACHE_HOME:-$HOME/.cache}"/torus/clip/*.img > /dev/null 2>&1 || bad+="thumbnail-not-healed[$("${QS[@]}" clipThumbs 2>/dev/null | tail -n 1)] "
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
  if [[ -z $bad ]]; then section clip ok "history with image thumbnail that heals when deleted, fuzzy filter, copy closes panel"; else section clip fail "$bad"; fi
}

clip_stat() { "${QS[@]}" clipStats 2>/dev/null | tail -n 1 | jq -r ".$1"; }

check_clipboard() {
  local bad="" db=${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/db share=${XDG_DATA_HOME:-$HOME/.local/share}/torus bak i n t open cold fmax before after
  "${QS[@]}" recallForget > /dev/null 2>&1
  export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
  bak=$(mktemp -d)
  cp -a "$db" "$bak/db" 2>/dev/null
  cp -a "$share/pins" "$bak/pins" 2>/dev/null; cp -a "$share/pins.json" "$bak/pins.json" 2>/dev/null
  "${QS[@]}" closeAll > /dev/null 2>&1
  cliphist wipe
  rm -rf "$share/pins" "$share/pins.json"
  "${QS[@]}" clipReload > /dev/null 2>&1
  for i in $(seq 1 995); do printf 'fixture entry %04d with some words to search through %s' "$i" "$((i * 7919 % 1000))" | cliphist -max-items 1100 store; done
  for i in 1 2 3 4 5; do magick -size $((40 + i))x30 xc:"hsl($((i * 60)),70%,60%)" png:- | cliphist -max-items 1100 store; done
  "${QS[@]}" clipToggle > /dev/null; sleep 3
  cold=$(clip_stat openMs)
  n=$(clip_stat matches)
  ((n >= 1000)) || bad+="fixture[$n] "
  "${QS[@]}" clipToggle > /dev/null; sleep 0.6
  "${QS[@]}" clipToggle > /dev/null; sleep 0.8
  open=$(clip_stat openMs)
  ((open >= 0 && open < 80)) || bad+="open[${open}ms] "
  "${QS[@]}" donutPaused true > /dev/null
  wtype -d 30 "fixture 07"; sleep 0.6
  "${QS[@]}" donutPaused false > /dev/null
  fmax=$(clip_stat filterMax)
  if ((${fmax%.*} >= 16)); then
    "${QS[@]}" clipToggle > /dev/null; sleep 0.8
    "${QS[@]}" clipToggle > /dev/null; sleep 1
    "${QS[@]}" donutPaused true > /dev/null
    wtype -d 30 "fixture 07"; sleep 0.6
    "${QS[@]}" donutPaused false > /dev/null
    fmax="$fmax then $(clip_stat filterMax)"
  fi
  i=${fmax##* }
  ((${i%.*} < 16)) || bad+="filter[${fmax}ms] "
  t=$("${QS[@]}" clipText 0 2>/dev/null | tail -n 1)
  [[ $t == "fixture entry 07"* || $t == "fixture entry 0"[0-9]"7"* ]] || bad+="rank[$t] "
  "${QS[@]}" clipToggle > /dev/null; sleep 0.6
  printf 'dedupe me %s' "$$" | wl-copy; sleep 0.8
  "${QS[@]}" clipToggle > /dev/null; sleep 1.2
  "${QS[@]}" clipFilter "dedupe me $$" > /dev/null; sleep 0.3
  "${QS[@]}" clipPin 0 > /dev/null; sleep 1.5
  "${QS[@]}" clipToggle > /dev/null; sleep 0.5
  printf 'something else %s' "$$" | wl-copy; sleep 0.6
  printf 'dedupe me %s' "$$" | wl-copy; sleep 0.8
  "${QS[@]}" clipToggle > /dev/null; sleep 3
  "${QS[@]}" clipFilter "dedupe me $$" > /dev/null; sleep 0.3
  n=$("${QS[@]}" clipCount 2>/dev/null | tail -n 1)
  [[ $n == 1 ]] || bad+="duplicate[$n] "
  wtype -k Delete; sleep 0.3
  [[ $("${QS[@]}" clipPinned 2>/dev/null | tail -n 1) == *"dedupe me $$"* ]] || bad+="pin-deleted-on-first-press "
  [[ $(clip_stat armed) == p:* ]] || bad+="not-armed "
  wtype -k Delete; sleep 0.5
  [[ $("${QS[@]}" clipPinned 2>/dev/null | tail -n 1) != *"dedupe me $$"* ]] || bad+="pin-not-deleted "
  "${QS[@]}" clipToggle > /dev/null; sleep 0.6
  "${QS[@]}" clipManage > /dev/null; sleep 1
  [[ $(clip_stat manage) == true ]] || bad+="no-manage "
  before=$(clip_stat matches)
  local gone
  gone=$("${QS[@]}" clipText 0 2>/dev/null | tail -n 1)
  wtype -k space; sleep 0.15; wtype -k space; sleep 0.15; wtype -k space; sleep 0.2
  [[ $(clip_stat marked) == 3 ]] || bad+="marked[$(clip_stat marked)] "
  wtype -k Delete; sleep 1
  after=$(clip_stat matches)
  ((before - after == 3)) || bad+="manage-delete[$before>$after] "
  cliphist list | grep -qF "$gone" && bad+="still-in-cliphist "
  "${QS[@]}" clipToggle > /dev/null; sleep 0.6
  "${QS[@]}" clipToggle > /dev/null; sleep 1
  wtype "entry 0500 with"; sleep 0.5
  t=$("${QS[@]}" clipText 0 2>/dev/null | tail -n 1)
  wtype -k Return; sleep 0.8
  [[ $(wl-paste --no-newline 2>/dev/null) == "$t" && -n $t ]] || bad+="enter-copy[$(wl-paste --no-newline 2>/dev/null | head -c 40)] "
  [[ $("${QS[@]}" isOpen clip 2>/dev/null | tail -n 1) == false ]] || bad+="still-open "
  cliphist wipe
  cp -a "$bak/db" "$db" 2>/dev/null
  rm -rf "$share/pins" "$share/pins.json"
  cp -a "$bak/pins" "$share/pins" 2>/dev/null; cp -a "$bak/pins.json" "$share/pins.json" 2>/dev/null
  rm -rf "$bak"
  "${QS[@]}" clipReload > /dev/null 2>&1
  if [[ -z $bad ]]; then section clipboard ok "1000 entries: open ${open} ms (cold ${cold} ms), slowest filter ${fmax} ms, a re-copied pin shows once, a pin needs two Del, select mode deletes the 3 selected, Enter copies"; else section clipboard fail "$bad"; fi
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
  wl-copy -p "segfault at 0x0 in libfoo" 2> /dev/null
  "${QS[@]}" paletteToggle > /dev/null; sleep 0.8
  "${QS[@]}" paletteQuery "!" > /dev/null; sleep 0.8
  "${QS[@]}" paletteRun 0 > /dev/null; sleep 3
  reply=$("${QS[@]}" aiLast 2>/dev/null | tr '\n' ' ')
  [[ $reply == *"segfault at 0x0 in libfoo"* ]] || bad+="explain-selection:[$reply] "
  wl-copy -p --clear 2> /dev/null
  echo "exit 1 in ~: make install" > "$XDG_RUNTIME_DIR/torus-last-error"
  "${QS[@]}" paletteToggle > /dev/null; sleep 0.8
  "${QS[@]}" paletteQuery "!" > /dev/null; sleep 0.8
  "${QS[@]}" paletteRun 0 > /dev/null; sleep 3
  reply=$("${QS[@]}" aiLast 2>/dev/null | tr '\n' ' ')
  [[ $reply == *"make install"* ]] || bad+="explain-last-error:[$reply] "
  rm -f "$XDG_RUNTIME_DIR/torus-last-error"
  [[ $("${QS[@]}" isOpen ai) == true ]] && "${QS[@]}" aiToggle > /dev/null
  kill "$pid" 2> /dev/null; rm -f "$mock"
  "${QS[@]}" aiRefresh > /dev/null 2>&1
  if [[ -z $bad ]]; then section ai ok "offline hint, models from /api/tags, streamed reply, explains the selection or the last failed command"; else section ai fail "$bad"; fi
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
  for i in $(seq 120); do
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
    sleep 36
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
  [[ $("${QS[@]}" meetingState) == "idle auto=true mic=true cam=false dnd=false joined=false" ]] || bad+="mic-alone[$("${QS[@]}" meetingState)] "
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
  "${QS[@]}" recallForget > /dev/null 2>&1
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
  printf '#!/bin/sh\nsleep 2\n[ -e /tmp/face-ok ] && exit 0\nexit 1\n' | sudo tee /usr/local/bin/fake-face > /dev/null
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

mixer_listed() { "${QS[@]}" mixerStreams 2>/dev/null | tail -n 1; }

check_mixer() {
  local bad="" r i seen="" t0 main blip=/tmp/parity-blip.wav loop=/usr/share/sounds/freedesktop/stereo/complete.oga mv
  [[ -s $blip ]] || ffmpeg -loglevel quiet -y -f lavfi -i "sine=frequency=880:duration=0.2" "$blip" < /dev/null
  main=$(hyprctl monitors -j | jq -r "sort_by(.id) | .[0].name")
  hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$main\" }))" > /dev/null; sleep 0.3
  "${QS[@]}" dashboardToggle > /dev/null; sleep 1
  [[ -z $(mixer_listed) ]] || bad+="not-empty-at-start[$(mixer_listed)] "
  for i in 1 2 3 4 5; do
    pw-play --media-role Event "$blip" &
    pw-play "$blip" &
    mpv --no-video --really-quiet --title=parity-mixer-short "$blip" &
    sleep 0.25
  done
  t0=$(date +%s%N)
  while (( ($(date +%s%N) - t0) < 2000000000 )); do
    r=$(mixer_listed); [[ -n $r ]] && seen+="$r "
    sleep 0.05
  done
  wait
  [[ -z $seen ]] || bad+="short-sounds-listed[$seen] "
  mpv --no-video --really-quiet --loop=inf --volume=40 "$loop" > /dev/null 2>&1 &
  mv=$!
  sleep 0.5
  [[ -z $(mixer_listed) ]] || bad+="listed-before-1s "
  sleep 1.2
  r=$(mixer_listed)
  [[ $r == *mpv* ]] || bad+="stream-missing[$r] "
  kill "$mv" 2>/dev/null; wait "$mv" 2>/dev/null
  sleep 0.8
  [[ -z $(mixer_listed) ]] || bad+="stream-stays[$(mixer_listed)] "
  local m
  m=$(MOTION_NS=torus-panel MOTION_OUTPUT=$main MOTION_DIR=$(mktemp -d) "$HERE/motion.sh" "sh:setsid -f mpv --no-video --really-quiet --loop=inf --volume=40 --title=parity-mixer-motion $loop" "sh:pkill -f ^mpv.*parity-mixer-motion" 2.5 2>&1 | tail -n 1)
  jq -e '.jumps == 0 and .resizes == 0 and .moves == 0' > /dev/null 2>&1 <<<"$m" || bad+="motion[$m] "
  pkill -f "^mpv.*parity-mixer-motion"
  "${QS[@]}" dashboardToggle > /dev/null
  if [[ -z $bad ]]; then section mixer ok "15 short sounds never listed, a playing app shows after 1 s [$r] and leaves when it stops, rows slide without jumps"; else section mixer fail "$bad"; fi
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

check_trash() {
  local bad="" d=~/Pictures/Screenshots f what
  mkdir -p "$d"
  rm -f "$d"/torus-parity-trash-*.png ~/.local/share/Trash/files/torus-parity-trash-* ~/.local/share/Trash/info/torus-parity-trash-*
  for what in Text Folder Delete; do
    f=$d/torus-parity-trash-$what.png
    magick -size 320x180 xc:'#313244' "$f"
    "${QS[@]}" islandFlash osd reset > /dev/null; sleep 0.2
    "${QS[@]}" screenshotShow "$f" > /dev/null; sleep 0.6
    "${QS[@]}" soundTake > /dev/null
    [[ $("${QS[@]}" screenshotAct "$what" | tail -n 1) == true ]] || bad+="$what-refused "
    sleep 0.8
    if [[ $what == Delete ]]; then
      [[ ! -e $f ]] || bad+="still-there "
      [[ -e ~/.local/share/Trash/files/torus-parity-trash-Delete.png ]] || bad+="not-in-trash "
      [[ $("${QS[@]}" soundTake | tail -n 1) == delete ]] || bad+="no-delete-sound "
      [[ $("${QS[@]}" islandState | tail -n 1) == *:trash* ]] || bad+="no-undo-after-island-delete "
    else
      [[ -e $f ]] || bad+="$what-removed-the-file "
      [[ $("${QS[@]}" soundTake | tail -n 1) != delete ]] || bad+="$what-played-delete "
    fi
    [[ $("${QS[@]}" islandState | tail -n 1) != *:shot* ]] || bad+="$what-island-stays "
  done
  sleep 1.5
  pkill -x dolphin 2> /dev/null; pkill -f "kitty \+open .*Screenshots" 2> /dev/null; "${QS[@]}" closeAll > /dev/null
  hyprctl clients -j | jq -r '.[] | select(.class == "org.kde.dolphin") | .pid' | xargs -r kill 2> /dev/null
  rm -f "$d"/torus-parity-trash-*.png ~/.local/share/Trash/files/torus-parity-trash-* ~/.local/share/Trash/info/torus-parity-trash-*
  if [[ -z $bad ]]; then section trash ok "island Delete moves the screenshot to the trash with the delete sound; Text and Folder keep it and stay quiet"; else section trash fail "$bad"; fi
}

check_undorace() {
  local bad="" d=~/Pictures/Screenshots i a b
  mkdir -p "$d"
  for i in $(seq 8); do (timeout 40 sh -c 'while :; do :; done' &); done
  for i in 1 2 3 4 5; do
    a=$d/torus-parity-race-a$i.png b=$d/torus-parity-race-b$i.png
    magick -size 64x64 xc:'#313244' "$a"; cp "$a" "$b"
    "${QS[@]}" screenshotShow "$a" > /dev/null; sleep 0.4
    "${QS[@]}" screenshotAct Delete > /dev/null; sleep 1
    "${QS[@]}" screenshotShow "$b" > /dev/null; sleep 0.4
    "${QS[@]}" screenshotAct Delete > /dev/null; "${QS[@]}" trashUndo > /dev/null
    sleep 2.5
    [[ -e $b ]] || bad+="b$i-not-back "
    [[ ! -e $a ]] || bad+="a$i-restored-instead "
  done
  pkill -f "while :; do :; d[o]ne"
  rm -f "$d"/torus-parity-race-* ~/.local/share/Trash/files/torus-parity-race-* ~/.local/share/Trash/info/torus-parity-race-*
  if [[ -z $bad ]]; then section undorace ok "Undo right after a delete brings back that file, never an older one, even under load"; else section undorace fail "$bad"; fi
}

check_envknobs() {
  local bad="" hits
  hits=$(grep -rlE 'TORUS_[A-Z_]*(API|URL|LOCAL|PLACE|OJP|FALLBACK|CLEAR|PORT)\b' ~/.local/bin/torus* ~/.config/quickshell/torus 2> /dev/null)
  [[ -z $hits ]] || bad+="env[$hits] "
  if [[ -z $bad ]]; then section envknobs ok "no installed helper takes a network address, a program or the password clear time from the environment"; else section envknobs fail "$bad"; fi
}

check_recall() {
  local bad="" d=~/Pictures/Screenshots a ca c first
  rs() { "${QS[@]}" recallState | tail -n 1; }
  ci() { "${QS[@]}" clipsState | tail -n 1 | cut -d'|' -f5; }
  mkdir -p "$d"
  magick -size 320x180 xc:'#89b4fa' "$d/torus-parity-recall-1.png"; sleep 1.1
  magick -size 320x180 xc:'#a6e3a1' "$d/torus-parity-recall-2.png"
  first=$(torus-games | head -n 1 | cut -f2)
  "${QS[@]}" closeAll > /dev/null; "${QS[@]}" recallForget > /dev/null
  "${QS[@]}" gamesToggle > /dev/null; sleep 1.5
  wtype -k Right; sleep 0.2; wtype -k Right; sleep 0.3
  wtype -k Tab; sleep 1.5
  wtype -k bracketright; sleep 0.3; wtype -M ctrl -k o -m ctrl; sleep 0.3; wtype -k Right; sleep 0.4
  a=$(rs) ca=$(ci)
  [[ $a == "hub=clips|"*"|"?*"|false|size;"* && $a != "hub=clips|$first|"* ]] || bad+="hub-setup[$a] "
  "${QS[@]}" gamesToggle > /dev/null; sleep 1; "${QS[@]}" gamesToggle > /dev/null; sleep 2
  [[ $(rs) == "$a" ]] || bad+="hub-kept[$(rs)] "
  [[ $(ci) == "$ca" ]] || bad+="clip-kept[$(ci) want $ca] "
  wtype -k Tab; sleep 0.5
  a=$(rs)
  "${QS[@]}" gamesToggle > /dev/null; sleep 1; "${QS[@]}" gamesToggle > /dev/null; sleep 0.4; wtype -k Right; sleep 2
  [[ $(rs) != "$a" && $(rs) == "hub=games|"* ]] || bad+="hub-move-undone[$(rs)] "
  "${QS[@]}" gamesToggle > /dev/null; sleep 0.6
  "${QS[@]}" captureToggle > /dev/null; sleep 2.5
  wtype -k bracketright; sleep 0.3; wtype -k Down; sleep 0.3; wtype -k Right; sleep 0.3
  c=$(rs)
  [[ $c == *";capture=image:torus-parity-recall-1.png;"* ]] || bad+="capture-setup[$c] "
  "${QS[@]}" captureToggle > /dev/null; sleep 1; "${QS[@]}" captureToggle > /dev/null; sleep 2.5
  [[ $(rs) == *";capture=image:torus-parity-recall-1.png;"* ]] || bad+="capture-kept[$(rs)] "
  "${QS[@]}" captureToggle > /dev/null; sleep 1; "${QS[@]}" captureToggle > /dev/null; sleep 0.4; wtype -k Left; sleep 2.5
  [[ $(rs) == *";capture=image:torus-parity-recall-2.png;"* ]] || bad+="capture-move-undone[$(rs)] "
  "${QS[@]}" captureToggle > /dev/null; sleep 0.6
  "${QS[@]}" clipToggle > /dev/null; sleep 0.8; wtype -k Tab; sleep 0.4
  [[ $(rs) == *";clip=text" ]] || bad+="clip-setup[$(rs)] "
  "${QS[@]}" clipToggle > /dev/null; sleep 0.8; "${QS[@]}" clipToggle > /dev/null; sleep 0.8
  [[ $(rs) == *";clip=text" ]] || bad+="clip-filter-kept[$(rs)] "
  "${QS[@]}" clipToggle > /dev/null; sleep 0.6
  "${QS[@]}" recallForget > /dev/null
  "${QS[@]}" gamesToggle > /dev/null; sleep 2
  [[ $(rs) == "hub=games|$first||false|new;"* ]] || bad+="hub-fresh[$(rs)] "
  "${QS[@]}" gamesToggle > /dev/null; sleep 0.6
  "${QS[@]}" captureToggle > /dev/null; sleep 2.5
  [[ $(rs) == *";capture=all:;"* ]] || bad+="capture-fresh[$(rs)] "
  "${QS[@]}" captureToggle > /dev/null; sleep 0.6
  "${QS[@]}" clipToggle > /dev/null; sleep 0.8
  [[ $(rs) == *";clip=all" ]] || bad+="clip-fresh[$(rs)] "
  "${QS[@]}" closeAll > /dev/null
  rm -f "$d"/torus-parity-recall-*
  if [[ -z $bad ]]; then section recall ok "game hub, capture studio and clipboard reopen where I left them, and fresh after 10 minutes closed"; else section recall fail "$bad"; fi
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
  local bad="" r share=${XDG_DATA_HOME:-$HOME/.local/share}/torus bak
  bak=$(mktemp -d)
  cp -a "$share/pins" "$bak/pins" 2> /dev/null; cp -a "$share/pins.json" "$bak/pins.json" 2> /dev/null
  rm -rf "$share/pins" "$share/pins.json"
  "${QS[@]}" clipReload > /dev/null 2>&1
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
  "${QS[@]}" clipPinned > /dev/null; sleep 1
  cliphist list | cut -f2- | grep -qx 'parity pinned text' || bad+="unpin-lost-the-text "
  [[ -z $(ls "$share/pins" 2> /dev/null) ]] || bad+="pin-file-left "
  [[ $(stat -c %a "$share/pins.json" 2> /dev/null) == 600 ]] || bad+="pins-json-mode[$(stat -c %a "$share/pins.json" 2> /dev/null)] "
  rm -rf "$share/pins" "$share/pins.json"
  cp -a "$bak/pins" "$share/pins" 2> /dev/null; cp -a "$bak/pins.json" "$share/pins.json" 2> /dev/null
  rm -rf "$bak"
  "${QS[@]}" clipReload > /dev/null 2>&1
  if [[ -z $bad ]]; then section pins ok "pinned entry survives a history wipe and copies back, unpinning gives it back to the history, pins.json is private"; else section pins fail "$bad"; fi
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
trap '"${QS[@]}" quietSet 0 6 > /dev/null 2>&1' EXIT

MOTION_PANELS=(
  "dashboard|dashboardToggle|dashboardToggle"
  "network|networkToggle|networkToggle"
  "updates|updatesToggle|updatesToggle"
  "theme|themeToggle|themeToggle"
  "capture|captureToggle|captureToggle"
  "session|sessionToggle|sessionToggle"
  "ocr|ocrShow|sh:wtype -k Escape"
  "popups|sh:notify-send -u critical -a parity motion popup|clearNotifs"
  "cheatsheet|cheatSheetToggle|cheatSheetToggle"
  "palette|paletteToggle|paletteToggle"
  "overview|overviewToggle|overviewToggle"
  "center|centerToggle|centerToggle"
  "clip|clipToggle|clipToggle"
  "games|gamesToggle|gamesToggle"
  "homelab|homelabToggle|homelabToggle"
  "ai|aiToggle|aiToggle"
  "processes|processesToggle|processesToggle"
)

check_motion() {
  command -v wf-recorder > /dev/null || { section motion fail "wf-recorder missing (VM fixture)"; return; }
  local bad="" out="" spec name open close r main
  main=$(hyprctl monitors -j | jq -r "sort_by(.id) | .[0].name")
  for spec in "${MOTION_PANELS[@]}"; do
    IFS='|' read -r name open close <<<"$spec"
    r=$(MOTION_OUTPUT=$main MOTION_DIR=$(mktemp -d) "$HERE/motion.sh" "$open" "$close" 2>&1 | tail -n 1)
    [[ $name != popups && $("${QS[@]}" isOpen "$name" 2>/dev/null) == true ]] && bad+="$name-stuck "
    if ! jq -e . > /dev/null 2>&1 <<<"$r"; then bad+="$name[$r] "; continue; fi
    out+="$name $(jq -r '"\(.resizes)r \(.moves)m \(.jumps)j \(.open_ms)/\(.close_ms)ms"' <<<"$r"); "
    jq -e '.resizes == 0 and .moves == 0 and .jumps == 0' > /dev/null <<<"$r" || bad+="$name "
    sleep 0.3
  done
  hyprctl eval 'hl.exec_cmd("kitty --class parity-mt-a")' > /dev/null
  hyprctl eval 'hl.exec_cmd("kitty --class parity-mt-b")' > /dev/null
  sleep 2
  r=$(MOTION_OUTPUT=$main MOTION_DIR=$(mktemp -d) "$HERE/motion.sh" "altTab next" "altTab apply" 2>&1 | tail -n 1)
  hyprctl clients -j | jq -r '.[] | select(.class | test("parity-mt-")) | .pid' | xargs -r kill
  [[ $("${QS[@]}" isOpen alttab 2>/dev/null) == true ]] && bad+="alttab-stuck "
  if jq -e . > /dev/null 2>&1 <<<"$r"; then
    out+="alttab $(jq -r '"\(.resizes)r \(.moves)m \(.jumps)j \(.open_ms)/\(.close_ms)ms"' <<<"$r"); "
    jq -e '.resizes == 0 and .moves == 0 and .jumps == 0' > /dev/null <<<"$r" || bad+="alttab "
  else
    bad+="alttab[$r] "
  fi
  local isl
  isl=$(MOTION_NS=torus-island MOTION_OUTPUT=$main MOTION_DIR=$(mktemp -d) "$HERE/motion.sh" "islandFlash osd parity-volume" "islandFlash notification parity-note" 1.0 2>&1 | tail -n 1)
  if jq -e . > /dev/null 2>&1 <<<"$isl"; then
    out+="island $(jq -r '"\(.resizes)r \(.jumps)j \(.open_ms)/\(.close_ms)ms"' <<<"$isl"); "
    jq -e '.resizes == 0 and .jumps == 0' > /dev/null <<<"$isl" || bad+="island "
  else
    bad+="island[$isl] "
  fi
  local win try ok=""
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "empty" }))' > /dev/null
  for try in 1 2; do
    win=$(MOTION_CROP=0,40,1280,760 MOTION_OUTPUT=$main MOTION_DIR=$(mktemp -d) "$HERE/motion.sh" "exec:kitty -o cursor_blink_interval=0 --class parity-motion-k" \
      "sh:hyprctl clients -j | jq -r '.[] | select(.class == \"parity-motion-k\") | .pid' | xargs -r kill" 3.0 2>&1 | tail -n 1)
    jq -e '.open_ms > 0 and .overshoot_px <= 6 and .close_ms <= .open_ms' > /dev/null 2>&1 <<<"$win" && { ok=1; break; }
  done
  out+="window $(jq -r '"\(.open_ms)/\(.close_ms)ms over \(.overshoot_px)px"' <<<"$win" 2>/dev/null); "
  [[ -n $ok ]] || bad+="window[$win] "
  if [[ -z $bad ]]; then section motion ok "$out"; else section motion fail "bad: $bad| $out"; fi
}

check_keys() {
  local bad="" seen="" l prev i dnd0
  "${QS[@]}" dashboardToggle > /dev/null; sleep 0.9
  [[ $("${QS[@]}" isOpen dashboard) == true ]] || bad+="no-dashboard "
  "${QS[@]}" setFocusLabel "" > /dev/null 2>&1
  for i in $(seq 8); do
    wtype -k Tab; sleep 0.15
    l=$("${QS[@]}" focusLabel 2>/dev/null | tail -n 1)
    [[ -n $l && " $seen " != *" ${l// /_} "* ]] && seen+="${l// /_} "
  done
  (($(wc -w <<<"$seen") >= 5)) || bad+="tab-chain[$seen] "
  [[ $("${QS[@]}" islandState 2>/dev/null) == *osd* ]] && bad+="virtual-keyboard-osd "
  prev=$(wc -w <<<"$seen")
  l=$("${QS[@]}" focusLabel 2>/dev/null | tail -n 1)
  wtype -M shift -k Tab -m shift; sleep 0.15
  [[ $("${QS[@]}" focusLabel 2>/dev/null | tail -n 1) != "$l" ]] || bad+="shift-tab "
  dnd0=$("${QS[@]}" dnd 2>/dev/null | tail -n 1)
  for i in $(seq 40); do
    [[ $("${QS[@]}" focusLabel 2>/dev/null | tail -n 1) == DND ]] && break
    wtype -k Tab; sleep 0.1
  done
  if [[ $("${QS[@]}" focusLabel 2>/dev/null | tail -n 1) == DND ]]; then
    wtype -k Return; sleep 0.3
    [[ $("${QS[@]}" dnd 2>/dev/null | tail -n 1) != "$dnd0" ]] || bad+="enter-dnd "
    wtype -k space; sleep 0.3
    [[ $("${QS[@]}" dnd 2>/dev/null | tail -n 1) == "$dnd0" ]] || bad+="space-dnd "
  else
    bad+="no-dnd-focus "
  fi
  "${QS[@]}" setDnd "$dnd0" > /dev/null 2>&1
  wtype -k Escape; sleep 0.5
  [[ $("${QS[@]}" isOpen dashboard) == false ]] || { bad+="esc "; "${QS[@]}" dashboardToggle > /dev/null; }
  if [[ -z $bad ]]; then section keys ok "Tab walks the dashboard ($prev stops: $seen), SHIFT+Tab goes back, Enter and Space press the focused button, Esc closes"; else section keys fail "$bad"; fi
}

cpu_ticks() { [[ -r /proc/$1/stat ]] || { echo "process $1 is gone" >&2; echo 999999999; return; }; awk '{print $14 + $15}' "/proc/$1/stat"; }

BUDGET_SHELL_PAUSED=${BUDGET_SHELL_PAUSED:-12}
BUDGET_HYPR_PAUSED=${BUDGET_HYPR_PAUSED:-80}
BUDGET_SHELL=${BUDGET_SHELL:-90}
BUDGET_HYPR=${BUDGET_HYPR:-300}

budget_sample() {
  local a b c d
  a=$(cpu_ticks "$1"); c=$(cpu_ticks "$2"); sleep 10; b=$(cpu_ticks "$1"); d=$(cpu_ticks "$2")
  echo "$(( (b - a) * 1000 / $3 / 10 )) $(( (d - c) * 1000 / $3 / 10 ))"
}

pct() { echo "$(($1 / 10)).$(($1 % 10))%"; }

check_cheatsheet() {
  local bad="" d
  d=$(hyprctl binds -j | jq -r '.[].description')
  grep -q 'select accent color\|select animations' <<<"$d" && bad+="old-wording "
  (($(grep -c 'theme studio' <<<"$d") == 4)) || bad+="theme-binds "
  "${QS[@]}" cheatSheetToggle > /dev/null; sleep 1
  [[ $("${QS[@]}" isOpen cheatsheet) == true ]] || bad+="not-open "
  wtype theme; sleep 0.4; wtype -k Escape; sleep 0.5
  [[ $("${QS[@]}" isOpen cheatsheet) == false ]] || { bad+="esc "; "${QS[@]}" closeAll > /dev/null; }
  torus_qml_warnings 2> /dev/null | grep -q 'keys.mjs\|CheatSheet' && bad+="qml-warning "
  if [[ -z $bad ]]; then section cheatsheet ok "theme binds say what they open, the sheet opens, searches and closes"; else section cheatsheet fail "$bad"; fi
}

check_popuprest() {
  local bad=""
  "${QS[@]}" closeAll > /dev/null; "${QS[@]}" clearNotifs > /dev/null
  (notify-send -u critical -a parity "rest" "popup" &) ; sleep 1
  (($("${QS[@]}" popupCount | tail -n 1) > 0)) || bad+="no-popup "
  [[ $("${QS[@]}" popupsResting | tail -n 1) == false ]] || bad+="resting-without-panel "
  for p in network updates session ai; do
    "${QS[@]}" "${p}Toggle" > /dev/null; sleep 0.5
    [[ $("${QS[@]}" popupsResting | tail -n 1) == true ]] || bad+="$p-does-not-rest "
    "${QS[@]}" closeAll > /dev/null; sleep 0.4
  done
  [[ $("${QS[@]}" popupsResting | tail -n 1) == false ]] || bad+="still-resting "
  (($("${QS[@]}" popupCount | tail -n 1) > 0)) || bad+="popup-lost "
  "${QS[@]}" clearNotifs > /dev/null
  if [[ -z $bad ]]; then section popuprest ok "a popup rests while network, updates, session or AI is open and comes back after"; else section popuprest fail "$bad"; fi
}

check_capturekeys() {
  local bad="" d=~/Pictures/Screenshots a b sel st
  "${QS[@]}" recallForget > /dev/null 2>&1
  mkdir -p "$d"
  rm -f "$d"/torus-parity-cap-* ~/.local/share/Trash/files/torus-parity-cap-* ~/.local/share/Trash/info/torus-parity-cap-*
  magick -size 640x360 xc:'#89b4fa' "$d/torus-parity-cap-1.png"; sleep 1.1
  magick -size 640x360 xc:'#a6e3a1' "$d/torus-parity-cap-2.png"
  "${QS[@]}" closeAll > /dev/null; "${QS[@]}" captureToggle > /dev/null; sleep 2.5
  wtype -k Down; sleep 0.3
  [[ $("${QS[@]}" captureSelected | tail -n 1) == */torus-parity-cap-2.png ]] || bad+="down[$("${QS[@]}" captureSelected | tail -n 1)] "
  wtype -k Right; sleep 0.3
  [[ $("${QS[@]}" captureSelected | tail -n 1) == */torus-parity-cap-1.png ]] || bad+="right "
  wtype -k space; sleep 0.5
  [[ $("${QS[@]}" quickLook | tail -n 1) == */torus-parity-cap-1.png ]] || bad+="look "
  wtype -k Left; sleep 0.3
  [[ $("${QS[@]}" quickLook | tail -n 1) == */torus-parity-cap-2.png ]] || bad+="look-next "
  wtype -k Escape; sleep 0.4
  [[ -z $("${QS[@]}" quickLook | tail -n 1) && $("${QS[@]}" isOpen capture) == true ]] || bad+="look-esc "
  wtype -k Delete; sleep 0.3
  [[ -e $d/torus-parity-cap-2.png ]] || bad+="one-del-deleted "
  wtype -k Delete; sleep 1
  [[ ! -e $d/torus-parity-cap-2.png && -e ~/.local/share/Trash/files/torus-parity-cap-2.png ]] || bad+="not-trashed "
  [[ $("${QS[@]}" islandState | tail -n 1) == *:trash* ]] || bad+="no-undo-on-island[$("${QS[@]}" islandState | tail -n 1)] "
  wtype -M ctrl -k z -m ctrl; sleep 1.2
  [[ -e $d/torus-parity-cap-2.png ]] || bad+="undo "
  st=$(torus-trash status)
  [[ $(jq -r .count <<<"$st") == 0 ]] || bad+="ledger[$st] "
  wtype -M ctrl -k Return -m ctrl; sleep 0.5
  wtype -k Escape; sleep 0.4
  [[ $("${QS[@]}" isOpen capture) == true ]] || bad+="no-sheet "
  torus-trash put "$d/torus-parity-cap-1.png" > /dev/null
  wtype -M ctrl -k Return -m ctrl; sleep 0.8
  wtype -k Delete; sleep 0.3; wtype -k Delete; sleep 1
  [[ $(torus-trash status | jq -r .count) == 0 && ! -e ~/.local/share/Trash/files/torus-parity-cap-1.png ]] || bad+="empty[$(torus-trash status)] "
  wtype -k Escape; sleep 0.3; wtype -k Escape; sleep 0.5
  [[ $("${QS[@]}" isOpen capture) == false ]] || { bad+="esc "; "${QS[@]}" closeAll > /dev/null; }
  rm -f "$d"/torus-parity-cap-* ~/.local/share/Trash/files/torus-parity-cap-* ~/.local/share/Trash/info/torus-parity-cap-*
  if [[ -z $bad ]]; then section capturekeys ok "arrows pick a capture, Space looks, Del twice trashes, Ctrl+Z brings it back, the sheet opens and empties torus's trash"; else section capturekeys fail "$bad"; fi
}

check_clips2() {
  local bad="" d=~/Videos/Clips/parity-two st i
  "${QS[@]}" recallForget > /dev/null 2>&1
  rm -rf "$d"; mkdir -p "$d"
  for i in 1 2 3; do
    ffmpeg -loglevel error -y -f lavfi -i "testsrc=duration=$((4 - i)):size=320x180:rate=10" -c:v libx264 -pix_fmt yuv420p "$d/parity-two-2026-11-0$i-100000.mp4" < /dev/null
    touch -d "2026-11-0$i 10:00" "$d/parity-two-2026-11-0$i-100000.mp4"
  done
  clip_info() { "${QS[@]}" clipsState | tail -n 1 | cut -d'|' -f"$1"; }
  "${QS[@]}" closeAll > /dev/null; "${QS[@]}" gamesToggle > /dev/null; sleep 1.2
  wtype -k Tab; sleep 1.5
  wtype parity; sleep 0.6
  [[ $(clip_info 6) == parity-two-2026-11-03-100000.mp4 ]] || bad+="newest-first[$(clip_info 6)] "
  wtype -M ctrl -k o -m ctrl; sleep 0.4
  [[ $(clip_info 1) == size && $(clip_info 6) == parity-two-2026-11-01-100000.mp4 ]] || bad+="sort[$("${QS[@]}" clipsState | tail -n 1)] "
  wtype -M ctrl -k o -m ctrl; sleep 0.3
  wtype -M ctrl -k m -m ctrl; sleep 0.3
  wtype -k space; sleep 0.2; wtype -k Right; sleep 0.2; wtype -k space; sleep 0.3
  [[ $(clip_info 2) == true && $(clip_info 3) == 2 ]] || bad+="marks[$("${QS[@]}" clipsState | tail -n 1)] "
  wtype -k Left; sleep 0.2; wtype -k Left; sleep 0.2; wtype -k Right; sleep 0.2; wtype -k Right; sleep 0.2
  wtype -k Right; sleep 0.2; wtype -k space; sleep 0.2; wtype -M ctrl -k s -m ctrl; sleep 0.5
  [[ $(clip_info 3) == 2 ]] || bad+="starring-did-not-unmark[$("${QS[@]}" clipsState | tail -n 1)] "
  wtype -k Left; sleep 0.2; wtype -k Left; sleep 0.2
  wtype -k Delete; sleep 0.3
  [[ -e $d/parity-two-2026-11-03-100000.mp4 ]] || bad+="one-del-deleted "
  wtype -k Delete; sleep 1.2
  [[ ! -e $d/parity-two-2026-11-03-100000.mp4 && ! -e $d/parity-two-2026-11-02-100000.mp4 && -e $d/parity-two-2026-11-01-100000.mp4 ]] || bad+="bulk-trash "
  [[ -e $d/parity-two-2026-11-01-100000.mp4 ]] || bad+="a-starred-clip-was-trashed "
  torus-play fav "$d/parity-two-2026-11-01-100000.mp4" off > /dev/null
  wtype -M ctrl -k z -m ctrl; sleep 1.5
  [[ -e $d/parity-two-2026-11-03-100000.mp4 && -e $d/parity-two-2026-11-02-100000.mp4 ]] || bad+="undo "
  wtype -k Escape; sleep 0.3
  [[ $(clip_info 2) == false && $("${QS[@]}" isOpen games) == true ]] || bad+="leave-manage "
  wtype -k F2; sleep 0.3
  [[ $(clip_info 4) == true ]] || bad+="no-rename-mode "
  for i in $(seq 30); do wtype -k BackSpace; done
  wtype "best round"; sleep 0.2; wtype -k Return; sleep 1.2
  [[ -e "$d/best round.mp4" ]] || bad+="rename[$(ls "$d" | paste -sd,)] "
  [[ $(clip_info 4) == false ]] || bad+="rename-stays-open "
  "${QS[@]}" closeAll > /dev/null
  rm -rf "$d" ~/.local/share/Trash/files/parity-two-* ~/.local/share/Trash/info/parity-two-*
  if [[ -z $bad ]]; then section clips2 ok "clips sort by size, select mode picks several and trashes them with undo, F2 renames"; else section clips2 fail "$bad"; fi
}

check_update() {
  local bad="" out
  out=$(bash "$REPO/tests/test_update.sh" 2>&1) || bad+="update[$(tail -n 1 <<<"$out")] "
  out=$(bash "$REPO/tests/test_prune.sh" 2>&1) || bad+="prune[$(tail -n 1 <<<"$out")] "
  out=$(bash "$REPO/tests/test_trashcan.sh" 2>&1) || bad+="trash[$(tail -n 1 <<<"$out")] "
  systemctl --user is-enabled torus-prune.timer > /dev/null 2>&1 || bad+="prune-timer-off "
  [[ $("${QS[@]}" torusState | tail -n 1) =~ ^[0-9a-f]*:[0-9]+:[0-9]+$ ]] || bad+="state[$("${QS[@]}" torusState | tail -n 1)] "
  torus-prune --dry-run > /dev/null || bad+="prune-run "
  if [[ -z $bad ]]; then section update ok "torus update fast-forwards signed commits only, the weekly prune keeps live previews, the trash ledger undoes and empties"; else section update fail "$bad"; fi
}

check_polish() {
  local bad="" ocr=$XDG_RUNTIME_DIR/torus-ocr.txt keep="" st fs0 fs1
  [[ -f $ocr ]] && keep=$(cat "$ocr")
  "${QS[@]}" closeAll > /dev/null
  : > "$ocr"; "${QS[@]}" ocrShow > /dev/null; sleep 0.8
  [[ $("${QS[@]}" polishState | tail -n 1 | jq -r .ocrEmpty) == true ]] || bad+="ocr-empty-not-seen "
  "${QS[@]}" closeAll > /dev/null; sleep 0.3
  printf 'hello\nworld\n' > "$ocr"; "${QS[@]}" ocrShow > /dev/null; sleep 0.8
  [[ $("${QS[@]}" polishState | tail -n 1 | jq -r .ocrEmpty) == false ]] || bad+="ocr-text-seen-as-empty "
  "${QS[@]}" closeAll > /dev/null
  if [[ -n $keep ]]; then printf '%s' "$keep" > "$ocr"; else rm -f "$ocr"; fi
  fs0=$("${QS[@]}" polishState | tail -n 1 | jq -r .fsMd)
  "${QS[@]}" feelSet textScale 1.15 > /dev/null; sleep 0.3
  fs1=$("${QS[@]}" polishState | tail -n 1 | jq -r .fsMd)
  "${QS[@]}" feelSet textScale 1 > /dev/null
  [[ $fs1 == 14 && $fs0 == 12 ]] || bad+="large-step[$fs0->$fs1] "
  grep -q 'layer.enabled: !Theme.dark' "$REPO/home/.config/quickshell/torus/bar/modules/Tray.qml" || bad+="tray-latte "
  if [[ -z $bad ]]; then section polish ok "OCR says when a picture has no text, the Large text step is 14 px, the tray darkens only on light flavors"; else section polish fail "$bad"; fi
}

check_gpuwatch() {
  local bad="" out
  pgrep -f "[t]orus-gpuwatch follow" > /dev/null || bad+="not-running "
  pgrep -f "[j]ournalctl -k -f" > /dev/null || bad+="no-kernel-follow "
  journalctl -k -b -n 1 -q --no-pager > /dev/null 2>&1 || bad+="kernel-log-unreadable "
  out=$(bash "$REPO/tests/test_gpuwatch.sh" 2>&1) || bad+="test[$(tail -n 1 <<<"$out")] "
  [[ $("${QS[@]}" gpuWatch | tail -n 1) == "{"* ]] || bad+="ipc "
  if [[ -z $bad ]]; then section gpuwatch ok "the shell follows kernel GPU resets, one plain notification per reset with Reboot now (the logout menu) and Later, never twice in a boot"; else section gpuwatch fail "$bad"; fi
}

check_rings() {
  local bad="" out="" spec name open want seen l w i
  for spec in "dashboard|dashboardToggle|previous_month next_month Mic" "network|networkToggle|Wi-Fi Bluetooth" "session|sessionToggle|toggle" \
    "theme|themeToggle|toggle" "homelab|homelabToggle|Refresh" "capture|captureToggle|segmented:all"; do
    IFS='|' read -r name open want <<<"$spec"
    "${QS[@]}" closeAll > /dev/null; sleep 0.3
    [[ $name == dashboard ]] && { "${QS[@]}" agendaRefresh > /dev/null; hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "empty" }))' > /dev/null; }
    "${QS[@]}" "$open" > /dev/null; sleep 0.9
    "${QS[@]}" setFocusLabel "" > /dev/null 2>&1
    seen=""
    for i in $(seq 26); do
      wtype -k Tab; sleep 0.08
      l=$("${QS[@]}" focusLabel 2>/dev/null | tail -n 1)
      [[ -n $l && " $seen " != *" ${l// /_} "* ]] && seen+="${l// /_} "
    done
    for w in $want; do [[ " $seen " == *" $w "* ]] || bad+="$name-misses-$w "; done
    out+="$name $(wc -w <<<"$seen"); "
    wtype -k Escape; sleep 0.4
    [[ $("${QS[@]}" isOpen "$name") == false ]] || { bad+="$name-esc "; "${QS[@]}" closeAll > /dev/null; }
  done
  if [[ -z $bad ]]; then section rings ok "Tab reaches every control, also the ones that were mouse only (stops: $out)"; else section rings fail "$bad[$out]"; fi
}

check_budget() {
  local bad="" qs hy hz t sp hp s h
  "${QS[@]}" closeAll > /dev/null 2>&1
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "empty" }))' > /dev/null
  qs=$(systemctl --user show -p MainPID --value torus-shell)
  hy=$(pgrep -xo Hyprland || pgrep -o -f '[H]yprland')
  hz=$(getconf CLK_TCK)
  "${QS[@]}" donutPaused true > /dev/null; sleep 3
  read -r sp hp < <(budget_sample "$qs" "$hy" "$hz")
  "${QS[@]}" donutPaused false > /dev/null; sleep 3
  read -r s h < <(budget_sample "$qs" "$hy" "$hz")
  t="donut paused: shell $(pct "$sp") (max $BUDGET_SHELL_PAUSED%), Hyprland $(pct "$hp") (max $BUDGET_HYPR_PAUSED%); donut on: shell $(pct "$s") (max $BUDGET_SHELL%), Hyprland $(pct "$h") (max $BUDGET_HYPR%)"
  ((sp <= BUDGET_SHELL_PAUSED * 10)) || bad+="shell-paused "
  ((hp <= BUDGET_HYPR_PAUSED * 10)) || bad+="hyprland-paused "
  ((s <= BUDGET_SHELL * 10)) || bad+="shell "
  ((h <= BUDGET_HYPR * 10)) || bad+="hyprland "
  if [[ -z $bad ]]; then section budget ok "idle 10 s, one core = 100%, VM renders on the CPU: $t"; else section budget fail "$bad| $t"; fi
}

flash_run() {
  local out=$1 action=$2 mon size mw mh mt rec
  mon=$(hyprctl monitors -j | jq -r 'sort_by(.id) | .[0].name')
  size=$(hyprctl monitors -j | jq -r 'sort_by(.id) | .[0] | "\(.width) \(.height) \(.transform)"')
  read -r mw mh mt <<<"$size"
  ((mt % 2 == 1)) && { local t=$mw; mw=$mh; mh=$t; }
  "${QS[@]}" donutPaused true > /dev/null 2>&1
  rm -f "$out"
  wf-recorder -D -r 30 -o "$mon" -c libx264rgb -p qp=0 -p preset=ultrafast -f "$out" > /dev/null 2>&1 &
  rec=$!
  for _ in $(seq 50); do [[ -s $out ]] && break; sleep 0.05; done
  sleep 1
  eval "$action"
  sleep 4
  kill -INT "$rec" 2> /dev/null; wait "$rec" 2> /dev/null
  "${QS[@]}" donutPaused false > /dev/null 2>&1
  FLASH_OFF=${3:-} python3 "$HERE/flash.py" "$out" "$mw" "$mh" "$(("${QS[@]}" barHeight 2>/dev/null | tail -n 1) || echo 28)" "$mt" 2>&1 | tail -n 1
}

check_flash() {
  command -v wf-recorder > /dev/null || { section flash fail "wf-recorder missing (VM fixture)"; return; }
  local bad="" out="" r dir name action
  dir=$(mktemp -d)
  "${QS[@]}" closeAll > /dev/null 2>&1
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "empty" }))' > /dev/null
  sleep 1
  for spec in "reload|${QS[*]} reload > /dev/null 2>&1" "resume|hyprctl eval 'hl.dispatch(hl.dsp.dpms({ action = \"off\" }))' > /dev/null; sleep 1.5; hyprctl eval 'hl.dispatch(hl.dsp.dpms({ action = \"on\" }))' > /dev/null"; do
    name=${spec%%|*}; action=${spec#*|}
    r=$(flash_run "$dir/$name.mkv" "$action" "$([[ $name == resume ]] && echo 1)")
    out+="$name $r; "
    jq -e '.bar_gone == 0 and .wall_gone == 0 and .black == 0' > /dev/null 2>&1 <<<"$r" || bad+="$name "
  done
  rm -rf "$dir"
  local d0
  d0=$("${QS[@]}" dnd 2>/dev/null | tail -n 1)
  "${QS[@]}" setDnd false > /dev/null; "${QS[@]}" focusToggle > /dev/null; sleep 0.5
  "${QS[@]}" reload > /dev/null 2>&1; sleep 4
  [[ $("${QS[@]}" dnd 2>/dev/null | tail -n 1) == true ]] || bad+="reload-dropped-focus-dnd "
  "${QS[@]}" focusToggle > /dev/null; sleep 0.5
  [[ $("${QS[@]}" dnd 2>/dev/null | tail -n 1) == false ]] || bad+="dnd-stuck-after-reload "
  "${QS[@]}" setDnd "$d0" > /dev/null
  if [[ -z $bad ]]; then section flash ok "bar and wallpaper never drop out, a focus session and its DND survive a reload: $out"; else section flash fail "$bad| $out"; fi
}

check_escape() {
  local bad="" name fn
  for name in dashboard center network; do
    case $name in dashboard) fn=dashboardToggle ;; center) fn=centerToggle ;; network) fn=networkToggle ;; esac
    "${QS[@]}" "$fn" > /dev/null; sleep 0.8
    [[ $("${QS[@]}" isOpen "$name") == true ]] || { bad+="$name-open "; continue; }
    wtype -k Escape; sleep 0.6
    [[ $("${QS[@]}" isOpen "$name") == false ]] || { bad+="$name-esc "; "${QS[@]}" "$fn" > /dev/null; }
  done
  "${QS[@]}" dashboardToggle > /dev/null; sleep 0.6
  "${QS[@]}" dashboardToggle > /dev/null; sleep 0.4
  [[ $("${QS[@]}" isOpen dashboard) == false ]] || bad+="dashboard-toggle "
  if [[ -z $bad ]]; then section escape ok "Esc closes dashboard, notification centre and network panel (focus grab), SUPER+D toggles"; else section escape fail "$bad"; fi
}

check_calm() {
  local bad="" a1 a2 b1 b2 st passes
  "${QS[@]}" calmForce true > /dev/null; sleep 3
  st=$("${QS[@]}" calmState 2>/dev/null | tail -n 1)
  [[ $st == on:calm:* ]] || bad+="state[$st] "
  passes=$(hyprctl getoption decoration:blur:passes -j | jq -r .int)
  [[ $passes == 1 ]] || bad+="blur-passes[$passes] "
  [[ $(torus-calm status) == on ]] || bad+="no-marker "
  a1=$("${QS[@]}" donutFrames Virtual-1 2>/dev/null); sleep 2; a2=$("${QS[@]}" donutFrames Virtual-1 2>/dev/null)
  [[ $a1 == "$a2" ]] || bad+="wallpaper-still-moving($a1>$a2) "
  "${QS[@]}" batteryMode full > /dev/null; sleep 3
  [[ $("${QS[@]}" calmState 2>/dev/null | tail -n 1) == off:full:* ]] || bad+="full-mode-ignored "
  "${QS[@]}" batteryMode calm > /dev/null
  "${QS[@]}" calmForce false > /dev/null; sleep 4
  passes=$(hyprctl getoption decoration:blur:passes -j | jq -r .int)
  [[ $passes == 3 ]] || bad+="blur-not-restored[$passes] "
  b1=$("${QS[@]}" donutFrames Virtual-1 2>/dev/null); sleep 2; b2=$("${QS[@]}" donutFrames Virtual-1 2>/dev/null)
  ((b2 > b1)) || bad+="wallpaper-not-resumed($b1=$b2) "
  if [[ -z $bad ]]; then section calm ok "on battery (forced): wallpaper rests, blur 3 -> 1 pass, full mode opts out, AC restores [$st]"; else section calm fail "$bad"; fi
}

island_has() {
  local i st
  for i in $(seq 24); do
    st=$("${QS[@]}" islandState 2>/dev/null | tail -n 1)
    if [[ $1 == yes ]]; then [[ $st == *:face* ]] && return 0; else [[ $st != *:face* ]] && return 0; fi
    sleep 0.25
  done
  return 1
}

check_faceisland() {
  local bad=""
  logger -t pam_howdy "Attempting facial authentication for user $USER"
  island_has yes || bad+="no-scan "
  logger -t pam_howdy "Login approved"
  sleep 0.5
  island_has yes || bad+="no-check "
  sleep 2.5
  island_has no || bad+="match-stuck "
  logger -t pam_howdy "Attempting facial authentication for user $USER"
  island_has yes || bad+="no-second-scan "
  logger -t pam_howdy "Failure, timeout reached"
  sleep 2.5
  island_has no || bad+="miss-stuck "
  if [[ -z $bad ]]; then section faceisland ok "pam_howdy journal lines drive the island: scan, check, miss, back to normal"; else section faceisland fail "$bad"; fi
}

feel_get() { "${QS[@]}" feelState 2>/dev/null | tail -n 1 | jq -r ".$1"; }

check_feel() {
  local bad="" d0 st
  "${QS[@]}" feelReset > /dev/null; sleep 0.5
  d0=$(feel_get durMed)
  "${QS[@]}" feelSet speed 1.5 > /dev/null; sleep 0.3
  (( $(feel_get durMed) < d0 )) || bad+="speed "
  "${QS[@]}" feelSet reduceMotion true > /dev/null; sleep 0.3
  [[ $(feel_get durMed) == 0 ]] || bad+="reduce-motion "
  "${QS[@]}" feelSet textScale 1.25 > /dev/null; sleep 0.3
  [[ $(feel_get fsMd) == 15 ]] || bad+="text-size[$(feel_get fsMd)] "
  "${QS[@]}" feelSet radius 0 > /dev/null; sleep 0.3
  [[ $(feel_get rPanel) == 0 ]] || bad+="radius "
  "${QS[@]}" feelList stay "dashboard network" > /dev/null; sleep 0.3
  [[ $(feel_get stayPut) == true ]] || bad+="stay "
  "${QS[@]}" feelList islandOff volume > /dev/null; sleep 0.3
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+ > /dev/null 2>&1; sleep 0.6
  st=$("${QS[@]}" islandState 2>/dev/null | tail -n 1)
  [[ $st == state:osd* ]] && bad+="volume-still-on-island "
  "${QS[@]}" feelList soundsOff notify > /dev/null; sleep 0.3
  [[ $(feel_get notify) == false ]] || bad+="sound-switch "
  [[ -s ~/.local/state/torus/feel.json ]] || bad+="not-persisted "
  "${QS[@]}" feelReset > /dev/null; sleep 0.5
  [[ $(feel_get durMed) == "$d0" && $(feel_get fsMd) == 12 && $(feel_get stayPut) == false ]] || bad+="reset "
  if [[ -z $bad ]]; then section feel ok "speed, reduce motion, text size, radius, panel follow, island and sound switches apply live and persist"; else section feel fail "$bad"; fi
}

check_homelab() {
  local bad="" st b=$HOME/.local/bin
  [[ -e $b/kubectl || -e $b/talosctl ]] && ! grep -q torus-parity-stub "$b/kubectl" 2> /dev/null && { section homelab fail "real kubectl in ~/.local/bin, refusing to stub"; return; }
  mkdir -p ~/.config/torus
  cp "$REPO/tests/fixtures/spire/kubectl" "$b/kubectl"; cp "$REPO/tests/fixtures/spire/talosctl" "$b/talosctl"; chmod +x "$b/kubectl" "$b/talosctl"
  echo '{"tailscale":["ironclad"],"amt":{"ironclad":"127.0.0.1"}}' > ~/.config/torus/spire.json
  python3 -m http.server 16993 --bind 127.0.0.1 > /dev/null 2>&1 &
  local web=$!
  sleep 0.5
  "${QS[@]}" homelabToggle > /dev/null; sleep 4
  [[ $("${QS[@]}" isOpen homelab) == true ]] || bad+="no-open "
  st=$("${QS[@]}" homelabState 2>/dev/null)
  [[ $st == ok:3:2:2:1 ]] || bad+="state[$st] "
  local m
  m=$("${QS[@]}" modules 2>&1)
  grep -q homelab <<<"$m" || bad+="no-chip-module "
  local mc port starts=0
  mc=$(mktemp -d)
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
  printf '#!/bin/sh\necho started >> %s/starts\nexec python3 -m http.server %s --bind 127.0.0.1 --directory %s\n' "$mc" "$port" "$mc" > "$mc/run.sh"
  chmod +x "$mc/run.sh"
  [[ -e $b/xdg-open ]] || { printf '#!/bin/sh\necho "$*" >> %s/opened\n' "$mc" > "$b/xdg-open"; chmod +x "$b/xdg-open"; }
  jq --arg u "http://127.0.0.1:$port/default.htm" --arg d "$mc" '. + { meshcommander: { url: $u, dir: $d } }' ~/.config/torus/spire.json > "$mc/conf" && cp "$mc/conf" ~/.config/torus/spire.json
  "${QS[@]}" homelabKvm > /dev/null; sleep 3
  "${QS[@]}" homelabKvm > /dev/null; sleep 2
  starts=$(wc -l < "$mc/starts" 2> /dev/null || echo 0)
  ((starts == 1)) || bad+="kvm-starts[$starts] "
  [[ $(sort -u "$mc/opened" 2> /dev/null) == "http://127.0.0.1:$port/default.htm" ]] || bad+="kvm-url[$(cat "$mc/opened" 2> /dev/null)] "
  pkill -f "http.server $port" 2> /dev/null
  grep -q "$mc" "$b/xdg-open" 2> /dev/null && rm -f "$b/xdg-open"
  rm -rf "$mc"
  "${QS[@]}" homelabToggle > /dev/null; sleep 0.4
  [[ $("${QS[@]}" isOpen homelab) == false ]] || bad+="no-close "
  kill "$web" 2> /dev/null
  rm -f "$b/kubectl" "$b/talosctl" ~/.config/torus/spire.json
  if [[ -z $bad ]]; then section homelab ok "SUPER+H hub reads nodes, pods, Flux, apps, routers and AMT from stubs [$st], read only; Remote KVM starts MeshCommander once and opens default.htm"; else section homelab fail "$bad"; fi
}

check_cutter() {
  local bad="" d=$HOME/Videos/Clips/hollow-knight c sum n dur
  "${QS[@]}" recallForget > /dev/null 2>&1
  mkdir -p "$d"
  c=$d/hollow-knight-2026-01-01-000000.mp4
  ffmpeg -v error -y -f lavfi -i testsrc2=s=640x360:r=30:d=12 -f lavfi -i sine=d=12 -c:v libx264 -g 60 -keyint_min 60 -sc_threshold 0 -pix_fmt yuv420p -c:a aac -shortest "$c"
  touch -d '2030-01-01' "$c"
  sum=$(md5sum < "$c")
  "${QS[@]}" closeAll > /dev/null 2>&1
  "${QS[@]}" gamesToggle > /dev/null; sleep 1.5
  wtype hollow; sleep 0.8
  wtype -k Tab; sleep 1.5
  wtype -M ctrl -k e -m ctrl; sleep 4
  for _ in 1 2 3; do wtype -k Right; sleep 0.1; done
  sleep 0.3; wtype "["; sleep 0.2
  for _ in 1 2 3 4; do wtype -k Right; sleep 0.1; done
  sleep 0.3; wtype "]"; sleep 0.3
  wtype -k Return; sleep 4
  n=$(ls "$d"/hollow-knight-2026-01-01-000000-cut-*.mp4 2> /dev/null | head -1)
  if [[ -z $n ]]; then
    bad+="no-cut "
  else
    dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$n")
    awk -v d="$dur" 'BEGIN { exit !(d >= 3.5 && d <= 6.5) }' || bad+="length[$dur] "
    [[ $(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$n" | wc -l) == 1 ]] || bad+="audio "
  fi
  [[ $(md5sum < "$c") == "$sum" ]] || bad+="original-changed "
  wtype -k Escape; sleep 0.5
  [[ $("${QS[@]}" isOpen games) == true ]] || bad+="esc-left-hub "
  "${QS[@]}" gamesToggle > /dev/null
  rm -f "$c" "$d"/hollow-knight-2026-01-01-000000-cut-*.mp4
  if [[ -z $bad ]]; then section cutter ok "Ctrl+E on a clip opens the cutter, [ and ] mark a part, Enter saves a ${dur%.*} s copy on keyframes, the original stays, Esc goes back to the hub"; else section cutter fail "$bad"; fi
}

check_steam() {
  local bad="" log=$HOME/.local/share/Steam/logs/shader_log.txt j st i
  mkdir -p "$(dirname "$log")"
  for i in 10 25 40; do
    echo "[$(date '+%F %T')] Still replaying 1145360 ($i%, $((i * 100))/10000)" >> "$log"
    sleep 4
  done
  j=$("${QS[@]}" steamJobs 2>/dev/null | tail -n 1)
  [[ $(jq -r '.[0] | "\(.kind):\(.name):\(.pct)"' <<<"$j" 2>/dev/null) == "shader:Hades:40" ]] || bad+="job[$j] "
  [[ $(jq -r '.[0].left' <<<"$j" 2>/dev/null) -gt 0 ]] || bad+="no-time-left[$j] "
  st=$("${QS[@]}" islandState 2>/dev/null)
  [[ $st == *progress* ]] || bad+="island[$st] "
  echo "[$(date '+%F %T')] Still replaying 1145360 (100%, 10000/10000)" >> "$log"
  sleep 3
  [[ $("${QS[@]}" steamJobs 2>/dev/null | tail -n 1) == "[]" ]] || bad+="not-finished "
  st=$("${QS[@]}" islandState 2>/dev/null)
  [[ $st == *notification* ]] || bad+="no-ready-note[$st] "
  if [[ -z $bad ]]; then section steam ok "Steam's shader log drives a progress ring on the island with time left, the hub card shows it, 100% says ready to play"; else section steam fail "$bad"; fi
}

check_steamheld() {
  local bad="" log=$HOME/.local/share/Steam/logs/shader_log.txt t id
  mkdir -p "$(dirname "$log")"
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "empty" }))' > /dev/null
  hyprctl eval 'hl.exec_cmd("kitty --class parity-held-full")' > /dev/null; sleep 2
  for _ in 1 2 3 4 5; do
    hyprctl clients -j | jq -e 'any(.[]; .class == "parity-held-full" and .fullscreen > 0)' > /dev/null && break
    hyprctl eval 'hl.dispatch(hl.dsp.window.fullscreen())' > /dev/null
    sleep 1
  done
  for id in 1145360 367520; do
    echo "[$(date '+%F %T')] Still replaying $id (50%, 5000/10000)" >> "$log"
  done
  sleep 3
  for id in 1145360 367520; do
    echo "[$(date '+%F %T')] Still replaying $id (100%, 10000/10000)" >> "$log"
  done
  sleep 3
  [[ $("${QS[@]}" islandState 2>/dev/null) != *notification* ]] || bad+="note-over-game "
  hyprctl clients -j | jq -r '.[] | select(.class == "parity-held-full") | .pid' | xargs -r kill
  sleep 1.5
  t=$("${QS[@]}" islandText 2>/dev/null | tail -n 1)
  [[ $t == notification\|* && $t == *Hades* && $t == *"Hollow Knight"* ]] || bad+="held[$t] "
  if [[ -z $bad ]]; then section steamheld ok "every Steam note held during a fullscreen game shows after it, in one line"; else section steamheld fail "$bad"; fi
}

check_gamesettings() {
  local bad="" before after h=$HOME/Videos/Clips/hades c=$HOME/Videos/Clips/hades/hades-2030-02-01-000000.mp4 mime
  "${QS[@]}" recallForget > /dev/null 2>&1
  before=$(torus-play settings 1145360 | jq -r .replay)
  "${QS[@]}" closeAll > /dev/null 2>&1
  "${QS[@]}" gamesToggle > /dev/null; sleep 1.5
  wtype hades; sleep 0.6
  wtype -M ctrl -k Return -m ctrl; sleep 1
  for _ in 1 2 3 4; do wtype -k Down; sleep 0.1; done
  wtype -k space; sleep 1
  after=$(torus-play settings 1145360 | jq -r .replay)
  [[ $before != "$after" && -n $after ]] || bad+="replay[$before>$after] "
  wtype -k space; sleep 1
  [[ $(torus-play settings 1145360 | jq -r .replay) == "$before" ]] || bad+="replay-back "
  wtype -k Escape; sleep 0.5
  [[ $("${QS[@]}" isOpen games) == true ]] || bad+="esc-closed-hub "
  mkdir -p "$h"
  ffmpeg -v error -y -f lavfi -i testsrc=s=640x360:r=30:d=2 -pix_fmt yuv420p "$c"
  touch -d '2030-02-01' "$c"
  rm -f /tmp/parity-xdg-open
  printf '#!/bin/sh\necho "$1" > /tmp/parity-xdg-open\n' > /tmp/parity-player; chmod +x /tmp/parity-player
  printf '[Desktop Entry]\nType=Application\nName=parity player\nExec=/tmp/parity-player %%f\nMimeType=video/mp4;\n' > ~/.local/share/applications/parity-player.desktop
  mime=$(xdg-mime query default video/mp4)
  xdg-mime default parity-player.desktop video/mp4
  wtype -k BackSpace -k BackSpace -k BackSpace -k BackSpace -k BackSpace; sleep 0.3
  wtype -k Tab; sleep 2
  wtype -k Return; sleep 2
  [[ $(cat /tmp/parity-xdg-open 2> /dev/null) == "$c" ]] || bad+="enter-plays[$(cat /tmp/parity-xdg-open 2> /dev/null)] "
  "${QS[@]}" gamesToggle > /dev/null
  [[ -n $mime ]] && xdg-mime default "$mime" video/mp4
  rm -f ~/.local/share/applications/parity-player.desktop /tmp/parity-player "$c"
  if [[ -z $bad ]]; then section gamesettings ok "Ctrl+Enter opens a game's settings, Space switches a row and saves it, Esc goes back, Enter on a clip plays it"; else section gamesettings fail "$bad"; fi
}

check_library() {
  local bad="" h=$HOME/Videos/Clips/hades fav=${XDG_STATE_HOME:-$HOME/.local/state}/torus/clip-favorites.json bak="" c lib
  "${QS[@]}" recallForget > /dev/null 2>&1
  mkdir -p "$h"
  [[ -f $fav ]] && bak=$(cat "$fav")
  rm -f "$fav"
  for c in 1 2; do
    ffmpeg -v error -y -f lavfi -i testsrc=s=640x360:r=30:d=3 -pix_fmt yuv420p "$h/hades-2030-01-0$c-000000.mp4"
    touch -d "2030-01-0$c" "$h/hades-2030-01-0$c-000000.mp4"
  done
  "${QS[@]}" closeAll > /dev/null 2>&1
  "${QS[@]}" gamesToggle > /dev/null; sleep 1.5
  wtype -M ctrl -k Tab -m ctrl; sleep 2.5
  wtype -M ctrl -k s -m ctrl; sleep 0.8
  jq -e --arg p "$h/hades-2030-01-02-000000.mp4" 'index($p) != null' "$fav" > /dev/null 2>&1 || bad+="star-newest[$(cat "$fav" 2> /dev/null)] "
  wtype "]"; sleep 0.4
  wtype -k Right; sleep 0.3
  wtype -M ctrl -k s -m ctrl; sleep 0.8
  lib=$(torus-play library)
  [[ $(awk -F'\t' '$8 == "1" { print $6 }' <<<"$lib" | sort -u | paste -sd,) == hades ]] || bad+="filter[$(awk -F'\t' '$8 == "1" { print $1 }' <<<"$lib" | xargs -r -n1 basename | paste -sd,)] "
  wtype -k Escape; sleep 0.5
  [[ $("${QS[@]}" isOpen games) == true ]] || bad+="esc-closed-hub "
  "${QS[@]}" gamesToggle > /dev/null
  systemctl --user restart torus-shell; sleep 6
  [[ $(torus-play library | awk -F'\t' '$8 == "1"' | wc -l) -ge 1 ]] || bad+="star-lost "
  rm -rf "$h"
  if [[ -n $bak ]]; then printf '%s\n' "$bak" > "$fav"; else rm -f "$fav"; fi
  if [[ -z $bad ]]; then section library ok "Ctrl+Tab opens every game's clips, Ctrl+S stars, ] filters by game, stars survive a shell restart, Esc goes back"; else section library fail "$bad"; fi
}

check_cleanup() {
  local bad="" v f t
  [[ $(torus-play budget) == 0 ]] || bad+="not-off-by-default "
  v=$(mktemp -d)
  mkdir -p "$v/Clips/celeste"
  for i in 1 2 3; do head -c 6000 /dev/zero > "$v/Clips/celeste/celeste-2001-01-0$i-000000.mp4"; touch -d "2001-01-0$i" "$v/Clips/celeste/celeste-2001-01-0$i-000000.mp4"; done
  t=$(mktemp --suffix=.mp4); head -c 6000 /dev/zero > "$t"
  f=$(XDG_VIDEOS_DIR=$v torus-play saved "$t")
  sleep 1
  [[ -f $v/Clips/celeste/celeste-2001-01-01-000000.mp4 ]] || bad+="off-trashed "
  rm -f "$f"
  mkdir -p "$v/bin"; printf '#!/bin/sh\n[ "$1" = put ] && mv "$2" "%s/trashed-$(basename "$2")"\n' "$v" > "$v/bin/torus-trash"; chmod +x "$v/bin/torus-trash"
  TORUS_CLIP_GB=1 torus-play budget 25 > /dev/null
  [[ $(PATH=$v/bin:$PATH XDG_VIDEOS_DIR=$v TORUS_CLIP_GB=1 torus-play cleanup | wc -l) -ge 1 ]] || bad+="on-kept-everything "
  ls "$v"/trashed-celeste-2001-01-01-000000.mp4 > /dev/null 2>&1 || bad+="oldest-not-trashed "
  torus-play budget 0 > /dev/null
  rm -rf "$v"
  if [[ -z $bad ]]; then section cleanup ok "clip disk budget is off by default and a saved clip trashes nothing; switched on, the oldest go to the trash first"; else section cleanup fail "$bad"; fi
}

steam_acf() { printf '"AppState"\n{\n\t"appid"\t\t"413150"\n\t"name"\t\t"Stardew Valley"\n\t"installdir"\t\t"Stardew Valley"\n\t"LastPlayed"\t\t"1762000000"\n\t"BytesToDownload"\t\t"%s"\n\t"BytesDownloaded"\t\t"%s"\n}\n' "$2" "$1" > "$3"; }

check_steamdl() {
  local bad="" st=$HOME/.local/share/Steam acf log j s bak
  acf=$st/steamapps/appmanifest_413150.acf log=$st/logs/content_log.txt
  bak=$(mktemp)
  cp "$acf" "$bak"
  mkdir -p "$st/logs"
  steam_acf 0 400000000 "$acf"
  echo "[$(date '+%F %T')] AppID 413150 update started : download 0/400000000, store 0/0, reuse 0/0, delta 0/0, stage 0/0" >> "$log"
  for i in 1 2 3; do sleep 3; steam_acf $((i * 60000000)) 400000000 "$acf"; done
  sleep 3
  j=$("${QS[@]}" steamJobs 2>/dev/null | tail -n 1)
  [[ $(jq -r '.[] | select(.kind == "download") | "\(.name):\(.pct)"' <<<"$j") == "Stardew Valley:45" ]] || bad+="job[$j] "
  [[ $("${QS[@]}" islandState 2>/dev/null) == *progress* ]] || bad+="no-ring "
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "empty" }))' > /dev/null
  hyprctl eval 'hl.exec_cmd("kitty --class parity-dl-full")' > /dev/null; sleep 2
  for _ in 1 2 3 4 5; do
    hyprctl clients -j | jq -e 'any(.[]; .class == "parity-dl-full" and .fullscreen > 0)' > /dev/null && break
    hyprctl eval 'hl.dispatch(hl.dsp.window.fullscreen())' > /dev/null
    sleep 1
  done
  sleep 1
  s=$("${QS[@]}" islandState 2>/dev/null)
  [[ $s != *progress* ]] || bad+="ring-over-game[$s] "
  steam_acf 400000000 400000000 "$acf"
  echo "[$(date '+%F %T')] AppID 413150 finished update (took 30 seconds)" >> "$log"
  sleep 2
  s=$("${QS[@]}" islandState 2>/dev/null)
  [[ $s != *notification* ]] || bad+="note-over-game "
  hyprctl clients -j | jq -r '.[] | select(.class == "parity-dl-full") | .pid' | xargs -r kill
  sleep 1.5
  [[ $("${QS[@]}" islandState 2>/dev/null) == *notification* ]] || bad+="no-note-after "
  cp "$bak" "$acf"; rm -f "$bak"
  if [[ -z $bad ]]; then section steamdl ok "Steam downloads: ring with speed and time left from the manifest, nothing over a fullscreen game, \"updated\" once it closes"; else section steamdl fail "$bad"; fi
}

check_ddc() {
  local bad="" b=$HOME/.local/bin d st i main
  [[ -e $b/ddcutil ]] && ! grep -q torus-parity-stub "$b/ddcutil" && { section ddc fail "real ddcutil in ~/.local/bin, refusing to stub"; return; }
  d=$(mktemp -d)
  main=$(hyprctl monitors -j | jq -r 'sort_by(.id) | .[0].name')
  printf '4 60\n7 30\n' > "$d/vcp"
  cat > "$b/ddcutil" << EOF
#!/usr/bin/env bash
# torus-parity-stub
echo "ddcutil \$*" >> "$d/log"
case " \$* " in
  *" detect "*) printf 'Display 1\n   I2C bus:  /dev/i2c-4\n   DRM connector:  card0-$main\n\nInvalid display\n   I2C bus:  /dev/i2c-9\n   DRM connector:  card0-SIDE\n' ;;
  *" getvcp 10 "*) bus=\$(sed -n 's/.*--bus \([0-9]*\).*/\1/p' <<< "\$*"); v=\$(awk -v b="\$bus" '\$1 == b {print \$2}' "$d/vcp"); [[ -n \$v ]] || exit 1; printf 'VCP 10 C %s 100\n' "\$v" ;;
  *" setvcp 10 "*) sleep 0.5; bus=\$(sed -n 's/.*--bus \([0-9]*\).*/\1/p' <<< "\$*"); v=\$(sed -n 's/.*setvcp 10 \([0-9]*\).*/\1/p' <<< "\$*"); awk -v b="\$bus" -v v="\$v" '\$1 == b {\$2 = v} {print}' "$d/vcp" > "$d/vcp.new" && mv "$d/vcp.new" "$d/vcp" ;;
esac
EOF
  chmod +x "$b/ddcutil"
  rm -f "$XDG_RUNTIME_DIR/torus/ddc.map"
  "${QS[@]}" dashboardToggle > /dev/null; sleep 3
  st=$("${QS[@]}" displaysState 2>/dev/null | tail -n 1)
  [[ $(jq -r '.levels | keys | join(",")' <<<"$st") == "$main" ]] || bad+="levels[$st] "
  local w0
  w0=$(jq -r .writes <<<"$st")
  "${QS[@]}" displaysSlide "$main" 41 50 > /dev/null
  sleep 2
  st=$("${QS[@]}" displaysState 2>/dev/null | tail -n 1)
  [[ $(( $(jq -r .writes <<<"$st") - w0 )) == 1 ]] || bad+="debounce[$(grep -c setvcp "$d/log")] "
  [[ $(awk '$1 == 4 {print $2}' "$d/vcp") == 50 ]] || bad+="last-value[$(cat "$d/vcp" | tr '\n' ' ')] "
  "${QS[@]}" dashboardToggle > /dev/null
  hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$main\" }))" > /dev/null
  [[ $("${QS[@]}" brightnessStep up 2>/dev/null | tail -n 1) == ok ]] || bad+="step "
  sleep 0.15
  [[ $("${QS[@]}" islandState 2>/dev/null) == *osd* ]] || bad+="osd-late "
  sleep 1.5
  [[ $(awk '$1 == 4 {print $2}' "$d/vcp") == 55 ]] || bad+="step-write[$(awk '$1 == 4 {print $2}' "$d/vcp")] "
  rm -f "$b/ddcutil" "$XDG_RUNTIME_DIR/torus/ddc.map"
  rm -rf "$d"
  "${QS[@]}" displaysRefresh > /dev/null 2>&1
  if [[ -z $bad ]]; then section ddc ok "monitor brightness over DDC: a monitor that does not answer is hidden, ten slider moves make one write, the key shows the OSD at once and the write follows"; else section ddc fail "$bad"; fi
}

check_btbattery() {
  local bad="" r k=parity-bt-$$ up
  up=$(( $(date +%s) - $(date -d "$(systemctl --user show -p ActiveEnterTimestamp --value torus-shell)" +%s) ))
  ((up >= 7)) || sleep $((7 - up))
  r=$("${QS[@]}" deviceBatteryFeed "$k" "WH-1000XM5" headphones 74 2>/dev/null | tail -n 1)
  [[ $r == "connect:WH-1000XM5:74" ]] || bad+="connect[$r] "
  sleep 0.3
  [[ $("${QS[@]}" islandState 2>/dev/null) == *osd* ]] || bad+="no-osd "
  sleep 3
  r=$("${QS[@]}" deviceBatteryFeed "$k" "WH-1000XM5" headphones 19 2>/dev/null | tail -n 1)
  [[ $r == "low:WH-1000XM5:19" ]] || bad+="low[$r] "
  sleep 0.3
  [[ $("${QS[@]}" islandState 2>/dev/null) == *notification* ]] || bad+="no-note "
  r=$("${QS[@]}" deviceBatteryFeed "$k" "WH-1000XM5" headphones 17 2>/dev/null | tail -n 1)
  [[ $r == "low:WH-1000XM5:19" ]] || bad+="warned-twice[$r] "
  "${QS[@]}" deviceBatteryFeed "$k" "WH-1000XM5" headphones 30 > /dev/null
  r=$("${QS[@]}" deviceBatteryFeed "$k" "WH-1000XM5" headphones 18 2>/dev/null | tail -n 1)
  [[ $r == "low:WH-1000XM5:18" ]] || bad+="no-rearm[$r] "
  r=$("${QS[@]}" deviceBatteryFeed "pad-$$" "" controller 55 2>/dev/null | tail -n 1)
  [[ $r == "connect:Controller:55" ]] || bad+="pad[$r] "
  if [[ -z $bad ]]; then section btbattery ok "headphones and controllers: battery on the island when they connect, one warning under 20 % until they are back over 25 %"; else section btbattery fail "$bad"; fi
}

check_downloads() {
  local bad="" d=${XDG_DOWNLOAD_DIR:-$HOME/Downloads} n=parity-dl-$$.bin st p0
  mkdir -p "$d"
  "${QS[@]}" clearNotifs > /dev/null 2>&1
  p0=$("${QS[@]}" popupCount 2>/dev/null | tail -n 1)
  : > "$d/$n"
  for i in 1 2 3; do head -c 400000 /dev/urandom >> "$d/$n.part"; sleep 1.2; done
  st=$("${QS[@]}" browserDownloads 2>/dev/null | tail -n 1)
  [[ $(jq -r '.jobs[0]' <<<"$st") == "$n:"* ]] || bad+="job[$st] "
  [[ $("${QS[@]}" islandState 2>/dev/null) == *progress* ]] || bad+="no-ring "
  mv "$d/$n.part" "$d/$n"
  sleep 2
  st=$("${QS[@]}" browserDownloads 2>/dev/null | tail -n 1)
  [[ $(jq -r .last <<<"$st") == "done:$n" ]] || bad+="not-done[$st] "
  [[ $("${QS[@]}" popupCount 2>/dev/null | tail -n 1) -gt ${p0:-0} ]] || bad+="no-actions-popup "
  "${QS[@]}" clearNotifs > /dev/null 2>&1
  pkill -f "notify-send -a Downloads" 2> /dev/null
  rm -f "$d/$n" "$d/$n.part"
  if [[ -z $bad ]]; then section downloads ok "a browser download shows a ring on the island with size and speed, then a notification with Open and Show in folder"; else section downloads fail "$bad"; fi
}

check_safeupdate() {
  local bad="" out rc
  "${QS[@]}" clearNotifs > /dev/null 2>&1
  local yb
  yb=$(mktemp -d)
  printf '#!/bin/sh\nexit 0\n' > "$yb/yay"; chmod +x "$yb/yay"
  out=$(printf 'y\n' | PATH=$yb:$PATH timeout 120 torus-updates upgrade 2>&1); rc=$?
  ((rc < 100)) || bad+="exit[$rc] "
  grep -q 'torus doctor' <<<"$out" || bad+="no-doctor "
  sleep 0.5
  [[ $("${QS[@]}" islandState 2>/dev/null) == *notification* ]] || bad+="no-island "
  printf '#!/bin/sh\nexit 1\n' > "$yb/yay"
  out=$(printf 'n\n' | PATH=$yb:$PATH timeout 60 torus-updates upgrade 2>&1); rc=$?
  rm -rf "$yb"
  ((rc != 0)) || bad+="failed-update-exit0 "
  if [[ -z $bad ]]; then section safeupdate ok "update from the panel: Arch news first, then yay, then torus doctor with the result on the island"; else section safeupdate fail "$bad| $(tail -n 3 <<<"$out" | tr '\n' ' ')"; fi
}

check_ruler() {
  local bad="" r want shot first main
  main=$(hyprctl monitors -j | jq -r 'sort_by(.id) | .[0].name')
  hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$main\" }))" > /dev/null; sleep 0.3
  torus-ruler; sleep 1.2
  first=$(ls "$XDG_RUNTIME_DIR"/torus-ruler-*.png 2> /dev/null)
  wtype -k Escape; sleep 0.5
  torus-ruler; sleep 1.5
  shot=$(ls "$XDG_RUNTIME_DIR"/torus-ruler-*.png 2> /dev/null)
  [[ -n $shot && $shot != "$first" && $(wc -l <<<"$shot") == 1 ]] || bad+="stale-frame[$first|$shot] "
  [[ $("${QS[@]}" isOpen ruler 2>/dev/null) == true ]] || bad+="no-overlay "
  want=$(python3 -c "from PIL import Image; im = Image.open('$shot').convert('RGB'); print('#%02x%02x%02x' % im.getpixel((640, 400)))" 2>/dev/null)
  r=$("${QS[@]}" rulerColorAt 640 400 2>/dev/null | tail -n 1)
  [[ $r == "$want" ]] || bad+="color[$r!=$want] "
  r=$("${QS[@]}" rulerMeasure 100 100 400 300 false 2>/dev/null | tail -n 1)
  [[ $r == "size:300x200" ]] || bad+="box[$r] "
  sleep 0.6
  [[ $(wl-paste -n 2>/dev/null) == 300x200 ]] || bad+="box-not-copied "
  r=$("${QS[@]}" rulerMeasure 100 100 400 500 true 2>/dev/null | tail -n 1)
  [[ $r == "distance:500 px" ]] || bad+="line[$r] "
  r=$("${QS[@]}" rulerStraight 100 100 400 110 2>/dev/null | tail -n 1)
  [[ $r == "distance:300 px@400,100" ]] || bad+="straight[$r] "
  r=$("${QS[@]}" rulerStraight 100 100 300 290 2>/dev/null | tail -n 1)
  [[ $r == "distance:276 px@295,295" ]] || bad+="diagonal[$r] "
  wtype -k Escape; sleep 0.5
  [[ $("${QS[@]}" isOpen ruler 2>/dev/null) == false ]] || { bad+="esc "; "${QS[@]}" closeAll > /dev/null; }
  if [[ -z $bad ]]; then section ruler ok "SUPER+Shift+M freezes the screen: a box gives W x H, Shift+drag a distance (500 px), Ctrl snaps it to 45° steps, the color under the cursor matches the pixel, all copied"; else section ruler fail "$bad"; fi
}

check_segv() {
  local bad="" d=${XDG_CACHE_HOME:-$HOME/.cache}/torus/crashes n0 n1 pid up
  up=$(( $(date +%s) - $(date -d "$(systemctl --user show -p ActiveEnterTimestamp --value torus-shell)" +%s) ))
  ((up >= 15)) || sleep $((15 - up))
  systemctl --user is-active --quiet torus-crash-watch.path || bad+="watch-off "
  n0=$(ls "$d"/*.log 2> /dev/null | wc -l)
  pid=$(pgrep -n -x qs || pgrep -n -f '^/usr/bin/qs -c torus')
  kill -SEGV "$pid"
  for _ in $(seq 40); do [[ $("${QS[@]}" isLocked 2>/dev/null | tail -n 1) == false ]] && break; sleep 0.5; done
  [[ $("${QS[@]}" isLocked 2>/dev/null | tail -n 1) == false ]] || bad+="shell-not-back "
  for _ in $(seq 20); do n1=$(ls "$d"/*.log 2> /dev/null | wc -l); ((n1 > n0)) && break; sleep 0.5; done
  ((n1 > n0)) || bad+="no-log "
  awake
  if [[ -z $bad ]]; then section segv ok "a segfault Quickshell restarts in place still leaves a torus crash log and a notification"; else section segv fail "$bad"; fi
}

check_battery() {
  local bad="" r
  r=$(torus-battery status)
  [[ $r == '{"present":false}' ]] || bad+="vm-has-battery[$r] "
  if [[ -z $bad ]]; then section battery ok "no battery here: no battery card, nothing touches a charge limit"; else section battery fail "$bad"; fi
}

check_psr() {
  local bad="" d out
  torus-doctor 2>&1 | grep -q ' psr ' && bad+="desktop-has-psr-line "
  d=$(mktemp -d)
  mkdir -p "$d/ps/BAT0" "$d/drm/card0/device" "$d/drv/amdgpu"
  ln -s "$d/drv/amdgpu" "$d/drm/card0/device/driver"
  out=$(TORUS_POWER_SUPPLY=$d/ps TORUS_DRM=$d/drm torus-doctor 2>&1)
  grep -qE 'ok +psr +no panel self refresh warnings this boot' <<<"$out" || bad+="laptop[$(grep psr <<<"$out")] "
  rm -rf "$d"
  if [[ -z $bad ]]; then section psr ok "torus doctor checks panel self refresh only on laptops, against this boot's kernel log"; else section psr fail "$bad"; fi
}

check_gsi() {
  local bad="" d port tok code saves
  d=$(mktemp -d)
  mkdir -p "$d/steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg"
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
  local path0=$PATH
  mkdir -p "$d/bin"
  printf '#!/bin/sh\n[ "$1" = -USR1 ] && cat "%s/torus/gsi-pending" >> "%s/saves"\nexit 0\n' "${XDG_STATE_HOME:-$HOME/.local/state}" "$d" > "$d/bin/pkill"
  chmod +x "$d/bin/pkill"
  sed "s/^PORT = 3471$/PORT = $port/" "$(command -v torus-gsi)" > "$d/bin/torus-gsi"; chmod +x "$d/bin/torus-gsi"
  grep -q "^PORT = $port$" "$d/bin/torus-gsi" || bad+="port-patch "
  export PATH=$d/bin:$PATH TORUS_STEAM=$d/steam TORUS_GSI_SAVE_DELAY=0
  torus-gsi install --quiet
  [[ -f "$d/steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/gamestate_integration_torus.cfg" ]] || bad+="no-cfg "
  tok=$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/torus/gsi-token")
  torus-gsi serve &
  local g=$!
  for _ in $(seq 50); do (exec 3<>/dev/tcp/127.0.0.1/$port) 2> /dev/null && break; sleep 0.1; done
  ss -ltnH "sport = :$port" | grep -q "127.0.0.1:$port" || bad+="not-loopback "
  while IFS= read -r line; do
    curl -s -o /dev/null --data "${line//TOKEN/$tok}" "http://127.0.0.1:$port/"
  done < "$REPO/tests/fixtures/gsi/match.jsonl"
  code=$(curl -s -o /dev/null -w '%{http_code}' --data '{"auth":{"token":"x"}}' "http://127.0.0.1:$port/")
  [[ $code == 403 ]] || bad+="token[$code] "
  sleep 0.5
  saves=$(paste -sd' ' "$d/saves" 2> /dev/null)
  [[ $saves == "ace clutch 3k" ]] || bad+="saves[$saves] "
  kill "$g" 2> /dev/null; wait "$g" 2> /dev/null
  torus-gsi uninstall > /dev/null
  export PATH=$path0
  unset TORUS_STEAM TORUS_GSI_SAVE_DELAY
  rm -rf "$d" "${XDG_STATE_HOME:-$HOME/.local/state}/torus/gsi-match.json"
  if [[ -z $bad ]]; then section gsi ok "CS2 game state on 127.0.0.1 with a token: ace, clutch and 3K save the replay, a wrong token gets 403, cfg written and removed"; else section gsi fail "$bad"; fi
}

check_play() {
  local bad="" st main clip r
  local state=~/.local/state/torus
  rm -f "$state/play-session.json" "$state/play-last.json"
  rm -rf ~/Videos/Clips/portal-2
  main=$(hyprctl monitors -j | jq -r '.[0].name')
  hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$main\" }))" > /dev/null
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "empty" }))' > /dev/null
  hyprctl eval 'hl.exec_cmd("kitty --class steam_app_620")' > /dev/null
  for _ in $(seq 100); do hyprctl clients -j | jq -e 'any(.[]; .class == "steam_app_620")' > /dev/null && break; sleep 0.2; done
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:steam_app_620" }))' > /dev/null 2>&1
  for _ in $(seq 10); do
    hyprctl clients -j | jq -e 'any(.[]; .class == "steam_app_620" and .fullscreen > 0)' > /dev/null && break
    hyprctl eval 'hl.dispatch(hl.dsp.window.fullscreen())' > /dev/null
    sleep 0.5
  done
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "empty" }))' > /dev/null; sleep 0.5
  hyprctl eval 'hl.dispatch(hl.dsp.focus({ window = "class:steam_app_620" }))' > /dev/null 2>&1
  for _ in $(seq 40); do [[ -s $state/play-session.json ]] && break; sleep 0.25; done
  st=$(jq -r '"\(.name):\(.class)"' "$state/play-session.json" 2> /dev/null)
  [[ $st == "Portal 2:steam_app_620" ]] || bad+="no-session[$st] "
  [[ ! -e $state/mangohud-log ]] || bad+="mangohud-logging "
  ffmpeg -v error -y -f lavfi -i testsrc=s=320x240:d=1 -c:v libx264 /tmp/parity-replay.mp4 < /dev/null
  clip=$(torus-play saved /tmp/parity-replay.mp4)
  [[ $clip == "$HOME/Videos/Clips/portal-2/portal-2-"*.mp4 && -f $clip ]] || bad+="clip[$clip] "
  [[ $(torus-play clips 620 | cut -f1) == "$clip" ]] || bad+="clips-list "
  for _ in $(seq 60); do pgrep -f "[t]orus-play start" > /dev/null || break; sleep 0.1; done
  jq '.start -= 600' "$state/play-session.json" > /tmp/parity-sess && cat /tmp/parity-sess > "$state/play-session.json"
  hyprctl clients -j | jq -r '.[] | select(.class == "steam_app_620") | .pid' | xargs -r kill
  for _ in $(seq 40); do [[ -s $state/play-last.json ]] && break; sleep 0.25; done
  r=$(torus-play recap | jq -r '"\(.name):\(.minutes):\(.clips)"')
  [[ $r == "Portal 2:10:1" ]] || bad+="recap[$r] "
  [[ ! -e $state/play-session.json ]] || bad+="session-left "
  [[ $(cat "$state/gamemode" 2> /dev/null || echo off) == off ]] || bad+="gamemode-stuck "
  rm -rf ~/Videos/Clips/portal-2 /tmp/parity-replay.mp4 "$state/play-last.json"
  if [[ -z $bad ]]; then section play ok "a fullscreen steam_app starts a play session, a clip files under Clips/portal-2, closing the game leaves a recap"; else section play fail "$bad"; fi
}

check_meetjoin() {
  local bad="" pid r
  "${QS[@]}" meetingNow false > /dev/null
  r=$("${QS[@]}" meetingJoin "https://example.com/not-a-call" 2>/dev/null | tail -n 1)
  [[ $r == false ]] || bad+="accepted-non-call "
  r=$("${QS[@]}" meetingJoin "https://meet.google.com/abc-defg-hij" 2>/dev/null | tail -n 1)
  [[ $r == true ]] || bad+="refused-meet "
  meeting_is "active" 10 || bad+="not-active "
  [[ $("${QS[@]}" meetingState) == *joined=true* ]] || bad+="not-joined "
  [[ $("${QS[@]}" dnd) == true ]] || bad+="dnd-not-on "
  pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=parity-mic media.class=Audio/Source/Virtual audio.position=[FL FR] object.linger=true }' > /dev/null
  sleep 1
  pw-record --target parity-mic /dev/null < /dev/null > /dev/null 2>&1 &
  pid=$!
  sleep 4
  kill "$pid" 2> /dev/null
  meeting_is "idle" 70 || bad+="call-end-not-noticed[$("${QS[@]}" meetingState)] "
  [[ $("${QS[@]}" dnd) == false ]] || bad+="dnd-not-restored "
  pw_drop parity-mic
  if [[ -z $bad ]]; then section meetjoin ok "Join opens only Meet/Teams/Zoom links, holds notifications at once, ends when the call releases the mic"; else section meetjoin fail "$bad"; fi
}

check_layout() {
  local bad="" ws0 ws1 n r
  mkdir -p /tmp/parity-proj && git -C /tmp/parity-proj init -q 2> /dev/null
  printf 'term\nterm\n' > /tmp/parity-proj/.torus-layout
  hyprctl eval 'hl.exec_cmd("kitty --class parity-layout-park")' > /dev/null
  for _ in $(seq 40); do hyprctl clients -j | jq -e 'any(.[]; .class == "parity-layout-park")' > /dev/null && break; sleep 0.25; done
  ws0=$(hyprctl activeworkspace -j | jq -r .id)
  torus-layout /tmp/parity-proj
  for _ in $(seq 40); do
    n=$(hyprctl clients -j | jq --argjson w "$(hyprctl activeworkspace -j | jq -r .id)" '[.[] | select(.class == "kitty" and .workspace.id == $w)] | length')
    ((n >= 2)) && break
    sleep 0.25
  done
  ws1=$(hyprctl activeworkspace -j | jq -r .id)
  [[ $ws1 != "$ws0" ]] || bad+="same-workspace "
  ((n == 2)) || bad+="windows[$n] "
  hyprctl clients -j | jq -r --argjson w "$ws1" '.[] | select(.workspace.id == $w) | .pid' | xargs -r kill
  hyprctl clients -j | jq -r '.[] | select(.class == "parity-layout-park") | .pid' | xargs -r kill
  rm -rf /tmp/parity-proj
  podman rm -f parity-proj-a > /dev/null 2>&1
  timeout 120 podman run -d --name parity-proj-a --label com.docker.compose.project=parityproj docker.io/library/busybox:1.37 sleep 100000 > /dev/null 2>&1 || bad+="fixture "
  r=$(torus-containers list | awk -F'\t' '$3 == "parity-proj-a" { print $7 }')
  [[ $r == parityproj ]] || bad+="project[$r] "
  torus-containers restart-project podman parityproj 2> /dev/null || bad+="restart-project "
  podman rm -f -t 0 parity-proj-a > /dev/null 2>&1
  if [[ -z $bad ]]; then section layout ok "a project's layout opens on its own workspace, containers carry their compose project and restart together"; else section layout fail "$bad"; fi
}

life_get() { "${QS[@]}" donutLife "$1" 2>/dev/null | tail -n 1 | cut -d: -f"$2"; }

check_living() {
  local bad="" main s0 s1 k0 k1 b1 pids="" i
  main=$(hyprctl monitors -j | jq -r 'sort_by(.id) | .[0].name')
  "${QS[@]}" wallpaper donut > /dev/null; sleep 2
  s0=$(life_get "$main" 1)
  [[ -n $s0 ]] || { section living fail "no life report (living donut off?)"; return; }
  for i in $(seq "$(nproc)"); do (timeout 8 sh -c 'while :; do :; done') & pids+="$! "; done
  sleep 6
  s1=$(life_get "$main" 1)
  wait $pids 2> /dev/null
  awk -v a="$s0" -v b="$s1" 'BEGIN { exit !(b > a + 0.5) }' || bad+="spin[$s0->$s1] "
  k0=$(life_get "$main" 4)
  notify-send -u critical -a parity "living" "wobble"; sleep 2.5
  k1=$(life_get "$main" 4)
  awk -v a="$k0" -v b="$k1" 'BEGIN { exit !(b > a || b >= 0.9) }' || bad+="no-wobble[$k0->$k1] "
  "${QS[@]}" clearNotifs > /dev/null
  "${QS[@]}" wallpaper xwing > /dev/null; sleep 2
  hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$main\" }))" > /dev/null
  local ws; ws=$(hyprctl activeworkspace -j | jq -r .id)
  hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = \"$(( ws == 7 ? 8 : 7 ))\" }))" > /dev/null; sleep 2.5
  hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = \"$ws\" }))" > /dev/null; sleep 1
  b1=$(life_get "$main" 3)
  awk -v b="$b1" 'BEGIN { exit !(b >= 5) }' || bad+="no-bank[$b1] "
  "${QS[@]}" wallpaper donut > /dev/null; sleep 1.5
  "${QS[@]}" donutPaused true > /dev/null; sleep 1.2
  pids=""
  for i in $(seq "$(nproc)"); do (timeout 3 sh -c 'while :; do :; done') & pids+="$! "; done
  sleep 2.5
  [[ $(life_get "$main" 1) == paused ]] || bad+="paused-donut-still-follows-load[$(life_get "$main" 1)] "
  wait $pids 2> /dev/null
  "${QS[@]}" donutPaused false > /dev/null; sleep 2.2
  [[ $(life_get "$main" 1) =~ ^[0-9.]+$ ]] || bad+="no-life-after-resume "
  if [[ -z $bad ]]; then section living ok "spin follows CPU load ($s0 -> $s1) and rests while the donut is paused, a notification wobbles it, the X-wing banks ($b1 deg)"; else section living fail "$bad"; fi
}

check_otp() {
  local bad="" r i idx
  wl-copy --clear 2> /dev/null
  notify-send -a parity "GitHub" "Your verification code is 482 913. It expires in 10 minutes."
  sleep 1
  "${QS[@]}" paletteToggle > /dev/null; sleep 0.8
  "${QS[@]}" paletteQuery "code" > /dev/null; sleep 1
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  [[ $r == *"Copy 482913"* ]] || bad+="no-palette-row[$r] "
  idx=$(tr '|' '\n' <<<"$r" | grep -n "Copy 482913" | cut -d: -f1 | head -1)
  [[ -n $idx ]] && "${QS[@]}" paletteRun $((idx - 1)) > /dev/null
  sleep 1
  [[ $(wl-paste -n 2> /dev/null) == 482913 ]] || bad+="not-copied "
  cliphist list 2> /dev/null | grep -q 482913 && bad+="in-clipboard-history "
  [[ $("${QS[@]}" isOpen palette) == true ]] && "${QS[@]}" paletteToggle > /dev/null
  sleep 0.5
  "${QS[@]}" paletteToggle > /dev/null; sleep 0.8
  "${QS[@]}" paletteQuery "n verification" > /dev/null; sleep 1
  r=$("${QS[@]}" paletteResults 2>/dev/null | tail -n 1)
  "${QS[@]}" paletteToggle > /dev/null
  [[ -n $r ]] || bad+="history-empty "
  "${QS[@]}" clearNotifs > /dev/null
  wl-copy --clear 2> /dev/null
  if [[ -z $bad ]]; then section otp ok "a code in a notification gets a palette row, copies as sensitive (not in cliphist)"; else section otp fail "$bad"; fi
}

check_crashlog() {
  local bad="" newest before
  before=$(torus-crash list 2> /dev/null | head -1)
  systemctl --user kill -s KILL torus-shell.service
  for _ in $(seq 60); do newest=$(torus-crash list 2> /dev/null | head -1); [[ -n $newest && $newest != "$before" ]] && break; sleep 0.5; done
  [[ -n $newest && $newest != "$before" ]] || bad+="no-log "
  for _ in $(seq 60); do [[ $("${QS[@]}" isLocked 2>/dev/null) == false ]] && break; sleep 0.5; done
  awake
  [[ $(TORUS_CRASH_CAT=1 torus-crash last | sed -n 2p) == "== QML warnings in this run" ]] || bad+="no-warnings-section "
  if [[ -z $bad ]]; then section crashlog ok "a crash log starts with the QML warnings of the run that crashed"; else section crashlog fail "$bad"; fi
}

check_fit() {
  local bad="" out="" spec name fn mon geo
  for mon in $(hyprctl monitors -j | jq -r '.[].name'); do
    hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$mon\" }))" > /dev/null; sleep 0.3
    for spec in dashboard:dashboardToggle theme:themeToggle capture:captureToggle network:networkToggle updates:updatesToggle session:sessionToggle homelab:homelabToggle processes:processesToggle; do
      name=${spec%%:*} fn=${spec#*:}
      "${QS[@]}" "$fn" > /dev/null; sleep 1
      geo=$(hyprctl layers -j | jq -r --arg m "$mon" '.[$m].levels[][] | select(.namespace == "torus-panel") | "\(.y + .h)"' | sort -n | tail -1)
      local bottom; bottom=$(hyprctl monitors -j | jq -r --arg m "$mon" '.[] | select(.name == $m) | .y + (if .transform % 2 == 1 then .width else .height end)')
      [[ -n $geo && $geo -le $bottom ]] || bad+="$mon:$name[$geo>$bottom] "
      "${QS[@]}" "$fn" > /dev/null; sleep 0.5
      [[ $("${QS[@]}" isOpen "$name") == true ]] && "${QS[@]}" "$fn" > /dev/null
    done
    out+="$mon "
  done
  if [[ -z $bad ]]; then section fit ok "every panel ends inside its screen ($out)"; else section fit fail "$bad"; fi
}

check_scopes() {
  local bad="" spec scope m
  for spec in apps windows files emoji glyphs calc web; do
    "${QS[@]}" paletteOpen "$spec" > /dev/null; sleep 0.6
    m=$("${QS[@]}" paletteMode); m=${m%%:*}
    [[ $("${QS[@]}" isOpen palette) == true && $m == "$spec" ]] || bad+="$spec[$m] "
    "${QS[@]}" paletteOpen "$spec" > /dev/null; sleep 0.4
    [[ $("${QS[@]}" isOpen palette) == false ]] || { bad+="$spec(toggle) "; "${QS[@]}" paletteToggle > /dev/null; }
  done
  "${QS[@]}" paletteOpen apps > /dev/null; sleep 0.4; "${QS[@]}" paletteOpen emoji > /dev/null; sleep 0.4
  m=$("${QS[@]}" paletteMode); [[ ${m%%:*} == emoji ]] || bad+="switch[$m] "
  "${QS[@]}" paletteToggle > /dev/null; sleep 0.4
  "${QS[@]}" paletteOpen glyphs > /dev/null; sleep 0.5; "${QS[@]}" paletteQuery "arch" > /dev/null; sleep 0.5
  [[ $("${QS[@]}" paletteResults) == *glyph:* ]] || bad+="glyph-results "
  "${QS[@]}" paletteToggle > /dev/null; sleep 0.4
  "${QS[@]}" paletteOpen web > /dev/null; sleep 0.5
  [[ $("${QS[@]}" paletteResults) == *"url:"* ]] || bad+="web-engines "
  "${QS[@]}" paletteToggle > /dev/null; sleep 0.4
  if [[ -z $bad ]]; then section scopes ok "SUPER+A, TAB, SHIFT+E, comma, period, SHIFT+K and SHIFT+/ open the palette in their scope and close it again"; else section scopes fail "$bad"; fi
}

check_qmllog() {
  local out
  out=$(torus_qml_warnings)
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
  trash) check_trash ;;
  panels) check_panels ;;
  pins) check_pins ;;
  smart) check_smart ;;
  session) check_session ;;
  qmllog) check_qmllog ;;
  motion) check_motion ;;
  keys) check_keys ;;
  rings) check_rings ;;
  gpuwatch) check_gpuwatch ;;
  polish) check_polish ;;
  popuprest) check_popuprest ;;
  capturekeys) check_capturekeys ;;
  clips2) check_clips2 ;;
  update) check_update ;;
  cheatsheet) check_cheatsheet ;;
  budget) check_budget ;;
  flash) check_flash ;;
  escape) check_escape ;;
  calm) check_calm ;;
  faceisland) check_faceisland ;;
  feel) check_feel ;;
  homelab) check_homelab ;;
  play) check_play ;;
  gsi) check_gsi ;;
  battery) check_battery ;;
  psr) check_psr ;;
  segv) check_segv ;;
  ruler) check_ruler ;;
  safeupdate) check_safeupdate ;;
  downloads) check_downloads ;;
  btbattery) check_btbattery ;;
  ddc) check_ddc ;;
  steamdl) check_steamdl ;;
  cleanup) check_cleanup ;;
  library) check_library ;;
  gamesettings) check_gamesettings ;;
  steam) check_steam ;;
  steamheld) check_steamheld ;;
  undorace) check_undorace ;;
  envknobs) check_envknobs ;;
  recall) check_recall ;;
  cutter) check_cutter ;;
  meetjoin) check_meetjoin ;;
  layout) check_layout ;;
  living) check_living ;;
  otp) check_otp ;;
  crashlog) check_crashlog ;;
  fit) check_fit ;;
  scopes) check_scopes ;;
  rules) check_rules ;;
  calendar) check_calendar ;;
  notify) check_notify ;;
  island) check_island ;;
  widgets) check_widgets ;;
  groups) check_groups ;;
  clip) check_clip ;;
  clipboard) check_clipboard ;;
  ai) check_ai ;;
  polkit) check_polkit ;;
  corners) check_corners ;;
  binds) check_binds ;;
  bar) check_bar ;;
  all) check_binds; check_bar; check_notify; check_island; check_groups; check_clip; check_clipboard; check_ai; check_widgets; check_corners; check_donut; check_dashboard; check_look; check_lock; check_spin; check_night; check_palette; check_palette2; check_projects; check_ssh; check_servers; check_cmddone; check_trust; check_github; check_scratch; check_meeting; check_overlay; check_containers; check_games; check_threads; check_displays; check_face; check_reload; check_follow; check_focus; check_switch; check_pass; check_mixer; check_shot; check_trash; check_undorace; check_envknobs; check_panels; check_pins; check_smart; check_session; check_rules; check_calendar; check_polkit; check_media; check_motion; check_keys; check_rings; check_polish; check_gpuwatch; check_popuprest; check_capturekeys; check_clips2; check_recall; check_update; check_cheatsheet; check_budget; check_flash; check_escape; check_calm; check_faceisland; check_feel; check_homelab; check_play; check_gsi; check_battery; check_psr; check_ruler; check_safeupdate; check_downloads; check_btbattery; check_ddc; check_steamdl; check_cleanup; check_library; check_gamesettings; check_steam; check_steamheld; check_cutter; check_meetjoin; check_layout; check_living; check_otp; check_crashlog; check_segv; check_fit; check_scopes; check_qmllog ;;
  *) echo "unknown section: $1" >&2; exit 1 ;;
esac
echo "parity: $passed/$total"
((passed == total))
