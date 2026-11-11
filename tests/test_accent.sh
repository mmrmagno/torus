#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/stubs.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export HOME=$F/home STUB_LOG=$F/calls XDG_STATE_HOME=$F/home/.local/state
mkdir -p "$HOME/.config/nvim/lua"
mkdesktopstubs "$F/bin"
export PATH=$F/bin:$PATH
T=$REPO/home/.local/bin/torus
S=$HOME/.local/state/torus

assert_eq 26 "$(jq 'keys | length' "$REPO/theme/mocha.json")" "palette size"
assert_eq '"#cba6f7"' "$(jq '.mauve' "$REPO/theme/mocha.json")" "mauve"

printf 'return { base46 = { theme = "catppuccin" } }\n' > "$HOME/.config/nvim/lua/chadrc.lua"
cp "$HOME/.config/nvim/lua/chadrc.lua" "$F/chadrc.orig"

"$T" accent blue > /dev/null
assert_eq blue "$("$T" accent)" "accent read back"
n=0
for t in "$REPO"/theme/templates/*.tmpl; do
  out=$S/theme/$(basename "$t" .tmpl)
  assert_file "$out"
  case ${out##*/} in
    cursor.env) assert_contains "$out" "XCURSOR_THEME=Bibata-Modern-Ice" ;;
    delta.gitconfig | starship.toml | yazi-theme.toml | lazygit.yml | zsh-colors.zsh | kvantum.kvconfig | qt6ct.conf | kdeglobals | rofi-config.rasi | gtk-settings.ini) ;;
    *) assert_contains "$out" "89b4fa" ;;
  esac
  grep -q '@[a-z_0-9]*@' "$out" && fail "placeholder left in $out"
  n=$((n + 1))
done
((n >= 7)) || fail "expected at least 7 templates, got $n"
assert_contains "$STUB_LOG" "qs -c torus ipc call torus reloadTheme"
assert_contains "$STUB_LOG" "hyprctl eval"
assert_contains "$STUB_LOG" "pkill -USR1 -x kitty"
[[ -e $HOME/.config/Kvantum/kvantum.kvconfig ]] && fail "accent must not touch the Kvantum theme"
grep -q 'setcursor catppuccin' "$STUB_LOG" && fail "accent must not change the cursor"
cmp -s "$F/chadrc.orig" "$HOME/.config/nvim/lua/chadrc.lua" || fail "chadrc without markers must stay untouched"

grep -q 'torus/theme/cursor.env' "$REPO/home/.config/uwsm/env" || fail "uwsm env must source cursor.env"
assert_contains "$HOME/.config/gtk-3.0/gtk.css" "89b4fa"
assert_contains "$HOME/.config/gtk-4.0/gtk.css" "89b4fa"
assert_contains "$HOME/.config/btop/themes/torus.theme" "89b4fa"

export GIT_CONFIG_GLOBAL=$F/gitconfig
printf '[user]\n\tname = marc\n' > "$GIT_CONFIG_GLOBAL"
: > "$STUB_LOG"
"$T" setup > /dev/null
"$T" setup > /dev/null
assert_eq 1 "$(git config --global --get-all include.path | grep -c 'torus/delta.gitconfig')" "delta include added once"
assert_eq marc "$(git config --global user.name)" "other git keys untouched"
assert_contains "$STUB_LOG" "gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark"
assert_contains "$STUB_LOG" "gsettings set org.gnome.desktop.interface color-scheme prefer-dark"
assert_contains "$STUB_LOG" "gsettings set org.gnome.desktop.interface icon-theme Tela-circle-dracula"
assert_contains "$STUB_LOG" "gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Ice"
assert_contains "$STUB_LOG" "bat cache --build"
assert_contains "$STUB_LOG" "fc-cache"
assert_contains "$STUB_LOG" "qsb "
grep -q '/donut.frag.qsb' "$STUB_LOG" || fail "setup compiles the donut shader"
grep -q '/torus.frag.qsb' "$STUB_LOG" || fail "setup compiles the torus shader"
assert_link "$HOME/.config/hypr/hyprtoolkit.conf" "$S/theme/hyprtoolkit.conf"
assert_contains "$HOME/.config/hypr/hyprtoolkit.conf" "accent = rgba(89b4faff)"
rm "$HOME/.config/hypr/hyprtoolkit.conf"; echo mine > "$HOME/.config/hypr/hyprtoolkit.conf"
"$T" setup > /dev/null
assert_eq mine "$(cat "$HOME/.config/hypr/hyprtoolkit.conf")" "own hyprtoolkit.conf kept"
assert_contains "$STUB_LOG" "systemctl --user enable torus-shell.service"
assert_contains "$STUB_LOG" "systemctl --user mask dunst.service"

cp -r "$S/theme" "$F/theme.before"
rc=0
"$T" accent nope > /dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "unknown accent exit code"
assert_eq blue "$("$T" accent)" "accent unchanged after bad name"
diff -r "$F/theme.before" "$S/theme" > /dev/null || fail "bad name changed rendered files"

Z=$HOME/.var/app/app.zen_browser.zen/.zen/abc.Default
mkdir -p "$Z" "$HOME/.var/app/app.zen_browser.zen/.zen/nope"
: > "$Z/prefs.js"
printf 'user_pref("browser.startup.page", 3);\n' > "$Z/user.js"
"$T" accent green > /dev/null
"$T" accent blue > /dev/null
grep -q '^user_pref("browser.startup.page", 3);$' "$Z/user.js" || fail "zen: other prefs kept"
assert_eq 1 "$(grep -c 'zen.theme.accent-color' "$Z/user.js")" "zen: one accent line after two changes"
grep -q "zen.theme.accent-color\", \"$(jq -r .accent "$S/theme/qs-colors.json")\"" "$Z/user.js" || fail "zen: follows the accent"
[[ ! -e $HOME/.var/app/app.zen_browser.zen/.zen/nope/user.js ]] || fail "zen: folders that are not profiles are left alone"

B=$HOME/.config/btop/btop.conf
rm -f "$B"; ln -s /nonexistent/btop.conf "$B"
"$T" accent blue > /dev/null
[[ -f $B && ! -L $B ]] || fail "btop: owns a real config file, not a link into the repo"
assert_contains "$B" 'color_theme = "torus"'
assert_contains "$B" 'vim_keys = true'
printf 'color_theme = "Default"\nupdate_ms = 500\n' > "$B"
"$T" accent green > /dev/null
assert_contains "$B" 'color_theme = "torus"'
assert_contains "$B" 'update_ms = 500'
