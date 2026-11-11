#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/home" "$F/proc/100/task/100" "$F/proc/300" "$F/repo/Web App/src"
git init -q "$F/repo/Web App"
export HOME=$F/home STUB_LOG=$F/calls TORUS_PROC=$F/proc PATH=$F/bin:$PATH TORUS_DROPDOWN_WAIT=1
echo 101 > "$F/proc/100/task/100/children"; ln -s "$F/home" "$F/proc/100/cwd"
mkdir -p "$F/proc/101"; echo zsh > "$F/proc/101/comm"; ln -s "$F/repo/Web App/src" "$F/proc/101/cwd"
ln -s / "$F/proc/300/cwd"
cat > "$F/bin/hyprctl" <<'S'
#!/usr/bin/env bash
echo "hyprctl $*" >> "$STUB_LOG"
case "$1" in
  activewindow) echo "${STUB_ACTIVE:-{\}}" ;;
  clients) echo "${STUB_CLIENTS:-[]}" ;;
esac
S
chmod +x "$F/bin/hyprctl"
T=$REPO/home/.local/bin/torus-dropdown

STUB_ACTIVE='{"class":"foot","pid":100}' "$T" --project
grep -qF 'hl.exec_cmd([==[kitty --class torus-dropdown-web-app --title [web-app] --directory '"'$F/repo/Web App'"']==], { workspace = "special:sc-web-app silent", float = true' "$STUB_LOG" || fail "spawns in the git root of the kitty shell: $(cat "$STUB_LOG")"
grep -q 'toggle_special("sc-web-app")' "$STUB_LOG" || fail "shows the project scratch"

: > "$STUB_LOG"
STUB_ACTIVE='{"class":"kitty","pid":100}' STUB_CLIENTS='[{"class":"torus-dropdown-web-app"}]' "$T" --project
grep -q exec_cmd "$STUB_LOG" && fail "an existing scratch is reused, not respawned"
grep -q 'toggle_special("sc-web-app")' "$STUB_LOG" || fail "reused scratch shown"

: > "$STUB_LOG"
STUB_ACTIVE='{"class":"torus-dropdown-web-app","pid":100}' "$T" --project
grep -q 'toggle_special("sc-web-app")' "$STUB_LOG" || fail "from inside the scratch it hides"
grep -q exec_cmd "$STUB_LOG" && fail "hiding spawns nothing"

: > "$STUB_LOG"
STUB_ACTIVE='{"class":"zen","pid":300}' "$T" --project
grep -q -- "--class torus-dropdown-home --title \[home\] --directory '$F/home'" "$STUB_LOG" || fail "no project falls back to home: $(cat "$STUB_LOG")"

: > "$STUB_LOG"
STUB_CLIENTS='[{"class":"torus-dropdown"}]' "$T"
grep -q 'toggle_special("term")' "$STUB_LOG" || fail "plain dropdown unchanged"

mkdir -p "$F/proc/400"; ln -s "$F/repo/Web App" "$F/proc/400/cwd"
: > "$STUB_LOG"
STUB_ACTIVE='{"class":"code","pid":400}' "$T" --project
grep -q 'special:sc-web-app' "$STUB_LOG" || fail "an editor in a repo uses its own folder"
