#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/home"
export HOME=$F/home XDG_DATA_HOME=$F/home/.local/share PATH=$F/bin:$PATH STUB_LOG=$F/calls
unset XDG_RUNTIME_DIR
printf '#!/bin/sh\necho "chromium $*" >> "$STUB_LOG"\n' > "$F/bin/chromium"
cat > "$F/bin/curl" <<'S'
#!/usr/bin/env bash
echo "curl $*" >> "$STUB_LOG"
out="" url=""
while [[ $# -gt 0 ]]; do case $1 in -o) out=$2; shift ;; -*) [[ $1 == --max-time || $1 == --max-filesize || $1 == -A ]] && shift ;; *) url=$1 ;; esac; shift; done
[[ -n $out ]] && exec > "$out"
case $url in
  https://linear.app/) printf '<html><head>\n<title>Linear – Plan and build products</title>\n<link rel="icon" href="/static/icon.png"></head></html>' ;;
  https://linear.app/static/icon.png) printf 'PNG' ;;
  https://app.slack.com/client) printf '<title>Slack</title>' ;;
  https://grafana.lab.test/) printf "<title>Grafana</title><link rel='shortcut icon' href='img/fav.png'>" ;;
  https://grafana.lab.test/img/fav.png) printf 'PNG' ;;
  https://bare.test/) printf '<title>Bare</title><link rel=icon href=/i.png>' ;;
  https://bare.test/i.png) printf 'PNG' ;;
  https://notion.so/) exit 22 ;;
  https://example.org/*) printf '<title>A very long title that goes on and on forever</title>' ;;
  *) exit 22 ;;
esac
S
cat > "$F/bin/magick" <<'S'
#!/usr/bin/env bash
src=${1%\[0\]}; [[ $(cat "$src") == PNG ]] || exit 1; for a; do out=$a; done; cp "$src" "$out"
S
chmod +x "$F/bin/"*
W=$REPO/home/.local/bin/torus-webapp
A=$XDG_DATA_HOME/applications

assert_eq "ok Linear" "$("$W" add https://linear.app/)" "name from the page title, first part"
d=$A/torus-webapp-linear.desktop
assert_file "$d"
grep -qx 'Exec=chromium "--user-data-dir='"$XDG_DATA_HOME"'/torus/webapps" --no-first-run --ozone-platform-hint=auto "--app=https://linear.app/"' "$d" || fail "exec line: $(grep Exec "$d")"
grep -qx 'StartupWMClass=chrome-linear.app__-Default' "$d" || fail "wm class matches chromium on wayland: $(grep WMClass "$d")"
grep -qx "Icon=$XDG_DATA_HOME/torus/webapp-icons/linear.png" "$d" || fail "icon from the page's link rel=icon: $(grep Icon= "$d")"
grep -q 'curl .*https://linear.app/static/icon.png' "$STUB_LOG" || fail "relative icon resolved against the host"
assert_eq "exists Linear" "$("$W" add https://linear.app/)" "same url twice is refused"

assert_eq "ok Slack" "$("$W" add 'https://app.slack.com/client')" "slack"
grep -qx 'StartupWMClass=chrome-app.slack.com__client-Default' "$A/torus-webapp-slack.desktop" || fail "wm class with a path"
grep -qx 'Icon=web-browser' "$A/torus-webapp-slack.desktop" || fail "no icon: generic web glyph"
assert_eq "ok Grafana" "$("$W" add https://grafana.lab.test/)" "single quotes and a relative icon"
grep -q '^Icon=.*/grafana.png$' "$A/torus-webapp-grafana.desktop" || fail "single-quoted icon"
assert_eq "ok Bare" "$("$W" add https://bare.test/)" "unquoted attributes"
grep -q '^Icon=.*/bare.png$' "$A/torus-webapp-bare.desktop" || fail "unquoted icon"
assert_eq "ok Notion" "$("$W" add https://notion.so/)" "page not reachable: name from the host"
assert_eq "ok Example" "$("$W" add 'https://example.org/a?b=1&c=%20')" "a long title falls back to the host"
grep -q -- '--app=https://example.org/a?b=1&c=%%20"$' "$A/torus-webapp-example.desktop" || fail "percent doubled in Exec"
assert_eq "ok Work tracker" "$("$W" add https://linear.app/team 'Work tracker')" "a given name wins"

for bad in 'https://x.org/"; rm -rf ~' 'https://x.org/$(id)' 'javascript:alert(1)' 'https://x.org/a b' 'file:///etc/passwd' 'https://x.org/`id`'; do
  assert_eq "bad-url" "$("$W" add "$bad")" "refused: $bad"
done
assert_eq "ok EvilExecrm -rf" "$("$W" add https://evil.org/ $'Evil\nExec=rm -rf ~')" "a name with a newline is cleaned"
assert_eq 1 "$(grep -c '^Exec=' "$A/torus-webapp-evilexecrm-rf.desktop")" "no second Exec line from the name"

assert_eq "ok" "$("$W" remove linear)" "remove"
assert_absent "$d"
assert_absent "$XDG_DATA_HOME/torus/webapp-icons/linear.png"
assert_eq "bad-name" "$("$W" remove ../../x)" "rm takes a slug only"
assert_eq "missing" "$("$W" remove nothing)" "rm of an unknown app"
mkdir -p "$F/bare"
for c in bash env; do ln -s "$(command -v "$c")" "$F/bare/$c"; done
assert_eq "no-chromium" "$(PATH=$F/bare "$W" add https://github.com/)" "no chromium"
echo "webapp: ok"
