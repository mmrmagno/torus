#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/stubs.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export HOME=$F/home STUB_LOG=$F/calls XDG_STATE_HOME=$F/home/.local/state
mkdir -p "$HOME/.config/nvim/lua" "$HOME/.config/vesktop"
mkdesktopstubs "$F/bin"
cat > "$F/bin/deno" <<'S'
#!/usr/bin/env bash
echo "deno $*" >> "$STUB_LOG"
[[ $* == *render-frames.ts* ]] && printf png > "${@: -4:1}/frame-0000.png"
exit 0
S
chmod +x "$F/bin/deno"
export PATH=$F/bin:$PATH
T=$REPO/home/.local/bin/torus
S=$HOME/.local/state/torus
P=$REPO/theme

for f in mocha macchiato frappe latte; do
  assert_eq "$(jq -c 'keys' "$P/mocha.json")" "$(jq -c 'keys' "$P/$f.json")" "$f palette keys"
done
assert_eq "#24273a #303446 #eff1f5" "$(jq -r .base "$P/macchiato.json" "$P/frappe.json" "$P/latte.json" | tr '\n' ' ' | sed 's/ $//')" "official bases"
assert_eq "#c6a0f6 #ca9ee6 #8839ef" "$(jq -r .mauve "$P/macchiato.json" "$P/frappe.json" "$P/latte.json" | tr '\n' ' ' | sed 's/ $//')" "official mauves"
assert_eq "#4c4f69 #dce0e8" "$(jq -r '.text, .crust' "$P/latte.json" | tr '\n' ' ' | sed 's/ $//')" "latte text and crust"

assert_eq mocha "$("$T" flavour)" "default flavour"
printf 'M = {}\n-- torus accent start\nM.torus_accent = "mauve"\n-- torus accent end\nreturn M\n' > "$HOME/.config/nvim/lua/chadrc.lua"
"$T" accent blue > /dev/null

for f in mocha macchiato frappe latte; do
  : > "$STUB_LOG"
  "$T" flavour "$f" > /dev/null
  assert_eq "$f" "$("$T" flavour)" "$f persisted"
  assert_eq "$f" "$(cat "$S/flavour")" "$f state file"
  assert_eq blue "$("$T" accent)" "accent kept across flavour"
  for t in "$P"/templates/*.tmpl; do
    assert_file "$S/theme/$(basename "$t" .tmpl)"
  done
  if grep -rlE '@[a-zA-Z_0-9]+@' "$S/theme" > "$F/left"; then fail "$f: placeholders left in $(cat "$F/left")"; fi
  q=$S/theme/qs-colors.json
  assert_eq "$f" "$(jq -r .flavour "$q")" "$f qs flavour"
  assert_eq boolean "$(jq -r '.dark | type' "$q")" "$f qs dark type"
  [[ $(jq -r .shadow "$q") =~ ^#[0-9a-f]{8}$ ]] || fail "$f: shadow is not #aarrggbb"
  assert_eq "$(jq -r .blue "$P/$f.json")" "$(jq -r .accent "$q")" "$f accent from its own palette"
  assert_contains "$S/theme/zsh-colors.zsh" "BAT_THEME=\"Catppuccin ${f^}\""
  assert_file "$REPO/home/.config/bat/themes/Catppuccin ${f^}.tmTheme"
  assert_contains "$S/theme/starship.toml" "palette = \"catppuccin_$f\""
  assert_contains "$S/theme/starship.toml" "accent = \"$(jq -r .blue "$P/$f.json")\""
  assert_contains "$S/theme/starship.toml" 'style = "bold accent"'
  assert_contains "$S/theme/starship.toml" 'style = "accent"'
  assert_contains "$S/theme/starship.toml" 'success_symbol = "[❯](bold accent)"'
  assert_contains "$S/theme/delta.gitconfig" "syntax-theme = Catppuccin ${f^}"
  assert_contains "$HOME/.config/vesktop/themes/torus.theme.css" "catppuccin-$f-blue.theme.css"
  assert_contains "$HOME/.config/nvim/lua/chadrc.lua" "M.torus_flavour = \"$f\""
  assert_contains "$HOME/.config/nvim/lua/chadrc.lua" 'M.torus_accent = "blue"'
  grep -q 'deno run .*render-frames.ts' "$STUB_LOG" || fail "$f: donut.png not re-rendered"
  grep -q 'deno run .*render-logo.ts' "$STUB_LOG" || fail "$f: fastfetch colours not re-rendered"
  assert_contains "$STUB_LOG" "bat cache --build"
  assert_contains "$STUB_LOG" "qs -c torus ipc call torus reloadTheme"
  for l in .config/Kvantum/kvantum.kvconfig .config/qt6ct/qt6ct.conf .config/kdeglobals .config/starship/starship.toml .config/yazi/theme.toml .config/lazygit/config.yml .config/gtk-3.0/settings.ini .config/gtk-4.0/settings.ini .config/hypr/hyprtoolkit.conf; do
    [[ -L $HOME/$l && -f $HOME/$l ]] || fail "$f: $l not linked into the state dir"
  done
  assert_contains "$HOME/.config/Kvantum/torus/torus.kvconfig" "highlight.color=$(jq -r --arg a "$(cat "$S/accent")" '.[$a]' "$P/$f.json")"
  if [[ $f == mocha ]]; then
    assert_contains "$HOME/.config/Kvantum/kvantum.kvconfig" "theme=torus"
    cmp -s "$REPO/home/.config/Kvantum/hyde-mocha/hyde-mocha.svg" "$HOME/.config/Kvantum/torus/torus.svg" || fail "mocha: kvantum keeps the HyDE look"
  else
    assert_contains "$HOME/.config/Kvantum/kvantum.kvconfig" "theme=torus"
    assert_file "$HOME/.config/Kvantum/torus/torus.kvconfig"
    assert_file "$HOME/.config/Kvantum/torus/torus.svg"
    assert_contains "$HOME/.config/Kvantum/torus/torus.svg" "$(jq -r .blue "$P/$f.json")"
    grep -qiF "$(jq -r .mauve "$P/$f.json")" "$HOME/.config/Kvantum/torus/torus.svg" && fail "$f: kvantum keeps the mauve accent"
    for k in base mantle crust text surface0 surface1 overlay0 subtext0; do
      hex=$(jq -r ".$k" "$P/mocha.json")
      grep -qxF "\"$hex\"" <(jq '.[]' "$P/$f.json") && continue
      if grep -rliF "${hex:1}" "$S/theme" > "$F/leak"; then fail "$f: mocha $k $hex leaks into $(cat "$F/leak")"; fi
    done
  fi
done

: > "$STUB_LOG"
"$T" flavour latte > /dev/null
L=$P/latte.json
assert_eq false "$(jq -r .dark "$S/theme/qs-colors.json")" "latte is light"
assert_contains "$STUB_LOG" "gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3"
grep -q 'gtk-theme adw-gtk3-dark' "$STUB_LOG" && fail "latte must not use the dark gtk theme"
assert_contains "$STUB_LOG" "gsettings set org.gnome.desktop.interface color-scheme prefer-light"
grep -q 'icon-theme Tela-circle$' "$STUB_LOG" || fail "latte uses the light icon theme"
assert_contains "$S/theme/gtk-settings.ini" "gtk-application-prefer-dark-theme=false"
assert_contains "$S/theme/hyprtoolkit.conf" "icon_theme = Tela-circle"
assert_contains "$S/theme/kitty.conf" "color0 $(jq -r .subtext1 "$L")"
assert_contains "$S/theme/kitty.conf" "color8 $(jq -r .subtext0 "$L")"
assert_contains "$S/theme/kitty.conf" "color7 $(jq -r .surface2 "$L")"
assert_contains "$S/theme/kitty.conf" "color15 $(jq -r .surface1 "$L")"
assert_contains "$S/theme/kitty.conf" "background $(jq -r .base "$L")"
assert_contains "$S/theme/delta.gitconfig" "dark = false"
assert_contains "$S/theme/lazygit.yml" "delta --light"
assert_contains "$S/theme/hyprlock-colors.conf" '$dim = 1.0'
"$T" accent red > /dev/null
assert_eq latte "$("$T" flavour)" "accent keeps the flavour"
assert_eq "$(jq -r .red "$L")" "$(jq -r .accent "$S/theme/qs-colors.json")" "accent uses the latte palette"
"$T" accent blue > /dev/null

: > "$STUB_LOG"
"$T" flavour mocha > /dev/null
assert_contains "$STUB_LOG" "gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark"
assert_contains "$STUB_LOG" "gsettings set org.gnome.desktop.interface color-scheme prefer-dark"
assert_contains "$STUB_LOG" "gsettings set org.gnome.desktop.interface icon-theme Tela-circle-dracula"
assert_contains "$S/theme/kitty.conf" "color0 #45475a"
assert_contains "$S/theme/kitty.conf" "color15 #a6adc8"
assert_contains "$S/theme/delta.gitconfig" 'minus-style = syntax "#53394c"'
assert_contains "$S/theme/delta.gitconfig" 'plus-style = syntax "#394545"'
assert_contains "$S/theme/hypr-colors.lua" 'rgba(11111bcc)'
assert_contains "$S/theme/hyprlock-colors.conf" '$dim = 0.55'
assert_contains "$S/theme/kdeglobals" "BackgroundNormal=24,24,37"
assert_eq '"#cc11111b"' "$(jq .shadow "$S/theme/qs-colors.json")" "mocha shadow"
if git -C "$REPO" cat-file -e HEAD:home/.config/starship/starship.toml 2> /dev/null; then
  for pair in starship/starship.toml:starship.toml yazi/theme.toml:yazi-theme.toml; do
    git -C "$REPO" show "HEAD:home/.config/${pair%%:*}" | cmp -s - "$S/theme/${pair#*:}" || fail "mocha ${pair#*:} differs from the pre-flavour file"
  done
fi

cp -r "$S/theme" "$F/theme.before"
rc=0
"$T" flavour espresso > /dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "unknown flavour exit code"
assert_eq mocha "$("$T" flavour)" "flavour unchanged after bad name"
diff -r "$F/theme.before" "$S/theme" > /dev/null || fail "bad flavour changed rendered files"

echo own > "$F/own"; rm "$HOME/.config/kdeglobals"; cp "$F/own" "$HOME/.config/kdeglobals"
"$T" flavour frappe > /dev/null
assert_eq own "$(cat "$HOME/.config/kdeglobals")" "own kdeglobals kept"

D=$F/deno
mkdir -p "$D/state/torus/theme"
cp "$S/theme/qs-colors.json" "$D/state/torus/theme/"
env -u TORUS_PALETTE PATH="${PATH#"$F/bin:"}" XDG_STATE_HOME=$D/state deno run --quiet --allow-read --allow-write --allow-env "$REPO/donut/render-logo.ts" "$D/ff" > /dev/null
r=$(jq -r .lavender "$P/frappe.json")
rgb="38;2;$((16#${r:1:2}));$((16#${r:3:2}));$((16#${r:5:2}))"
assert_contains "$D/ff/config.jsonc" "$rgb"
env PATH="${PATH#"$F/bin:"}" XDG_STATE_HOME=$D/none TORUS_PALETTE=$P/latte.json deno run --quiet --allow-read --allow-write --allow-env "$REPO/donut/render-logo.ts" "$D/ff2" > /dev/null
r=$(jq -r .lavender "$P/latte.json")
assert_contains "$D/ff2/config.jsonc" "38;2;$((16#${r:1:2}));$((16#${r:3:2}));$((16#${r:5:2}))"
env PATH="${PATH#"$F/bin:"}" XDG_STATE_HOME=$D/none deno run --quiet --allow-read --allow-write --allow-env "$REPO/donut/render-logo.ts" "$D/ff3" > /dev/null
cmp -s "$D/ff3/config.jsonc" "$REPO/home/.config/fastfetch/config.jsonc" || fail "no state means the mocha fastfetch config"
: > "$STUB_LOG"; "$T" flavour macchiato > /dev/null; "$T" flavour frappe > /dev/null
grep -q 'restart --no-block torus-shell' "$STUB_LOG" && fail "dark to dark keeps the shell running"
: > "$STUB_LOG"; "$T" flavour latte > /dev/null
grep -q 'restart --no-block torus-shell' "$STUB_LOG" || fail "dark to light restarts the shell for the icon theme"
: > "$STUB_LOG"; "$T" flavour mocha > /dev/null
grep -q 'restart --no-block torus-shell' "$STUB_LOG" || fail "light to dark restarts the shell"
true
