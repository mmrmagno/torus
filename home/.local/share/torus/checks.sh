# Checks shared by torus doctor --parity (torus-parity) and the VM suite (vm/parity.sh). Source it, do not run it.

torus_bind_list() {
  hyprctl binds -j | jq -r '
    def mods: [ (if (.modmask/64|floor)%2==1 then "SUPER" else empty end), (if (.modmask/4|floor)%2==1 then "CTRL" else empty end), (if (.modmask/8|floor)%2==1 then "ALT" else empty end), (if .modmask%2==1 then "SHIFT" else empty end)] | join("+");
    .[] | ((mods) as $m | if $m=="" then .key else $m+"+"+.key end) + (if .release then " release" else "" end)' | sort -u
}

torus_binds_missing() {
  comm -23 <(sort -u "$1") <(torus_bind_list) | tr '\n' ' '
}

torus_config_errors() {
  hyprctl configerrors 2>&1 | grep -v '^\s*$' | head -3 | tr '\n' ' '
}

TORUS_QML_BAD='WARN qml|ERROR|TypeError|ReferenceError|[Bb]inding loop|Unable to assign|unavailable|is not a function|Cannot read property'
TORUS_QML_IGNORE='dmabuf: Failed to find render device|dmabuf|quickshell\.dbus|crashreporter|Quickshell has (crashed|been restarted)|Further crash information'

torus_qml_warnings() {
  local inv
  inv=$(systemctl --user show -p InvocationID --value torus-shell 2> /dev/null)
  journalctl --user -u torus-shell "_SYSTEMD_INVOCATION_ID=$inv" --no-pager -o cat 2> /dev/null | sed 's/\x1b\[[0-9;]*m//g' |
    if [[ ${1:-} == --since-load ]]; then awk '/Configuration Loaded/ { buf = ""; next } { buf = buf $0 "\n" } END { printf "%s", buf }'; else cat; fi |
    grep -E "$TORUS_QML_BAD" | grep -vE "$TORUS_QML_IGNORE" | sort -u | head -5
}

torus_sound_probe() {
  local f=/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga seen=0
  [[ -f $f ]] || { echo missing; return; }
  setsid -f pw-play --volume 0.05 "$f" > /dev/null 2>&1 < /dev/null
  for _ in $(seq 15); do
    seen=$(pw-dump 2> /dev/null | jq -r '[.[] | select(.type == "PipeWire:Interface:Node" and .info.props["media.class"] == "Stream/Output/Audio" and (.info.props["application.name"] // "" | test("pw-play|pw-cat")))] | length')
    [[ ${seen:-0} -gt 0 ]] && break
    sleep 0.1
  done
  echo "${seen:-0}"
}
