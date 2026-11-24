#!/usr/bin/env bash
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
qmp=${1:-$HOME/vms/torus/dev.qmp}
vm() { "$here/torus-vm" ssh 'export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1); export PATH=$HOME/.local/bin:$PATH; Q="qs -c torus ipc call torus"; '"$*"; }
read -r x0 y0 x1 y1 < <(vm 'hyprctl monitors -j | jq -r "[(map(.x) | min), (map(.y) | min), (map(.x + (if .transform % 2 == 1 then .height else .width end)) | max), (map(.y + (if .transform % 2 == 1 then .width else .height end)) | max)] | @tsv"')
click() { python3 "$here/qmp-mouse.py" "$qmp" $((x1 - x0)) $((y1 - y0)) "$(($1 - x0 - 1)),$(($2 - y0))" "$(($1 - x0)),$(($2 - y0))" click; sleep 0.8; }
panel() { read -r px py pw ph < <(vm 'hyprctl layers -j | jq -r ".. | objects | select(.namespace? == \"torus-panel\") | [.x, .y, .w, .h] | @tsv" | head -1'); }
say() { vm "\$Q $* | tail -1"; }
start() { vm '$Q closeAll; $Q recallForget; sleep 0.6; hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"Virtual-1\" }))"; '"$*" > /dev/null 2>&1; panel; }
bad="" out=""

vm 'sudo nmcli radio wifi on' > /dev/null 2>&1
start '$Q networkToggle; sleep 1; $Q wifiQr NotHere; sleep 1.2'
click $((px + pw - 35)) $((py + 60))
[[ $(vm 'nmcli radio wifi') == enabled ]] || bad+="wifi-switch-under-the-qr "
[[ $(say wifiQrState) == not-connected ]] || bad+="qr-closed-by-a-click "
vm 'sudo nmcli radio wifi on' > /dev/null 2>&1
out+="Wi-Fi QR, "

start 'rm -rf ~/parity-sheet; mkdir -p ~/parity-sheet/in; touch ~/parity-sheet/{a,b,c,d}.txt; $Q paletteQuery "~/parity-sheet/"; sleep 1.5; wtype -M shift -k space -m shift; sleep 1.2'
click $((px + pw / 2)) $((py + 160)); click $((px + pw / 2)) $((py + 200))
[[ $(say isOpen palette) == true && $(say paletteLook) != off ]] || bad+="result-under-the-file-preview[$(say isOpen palette) $(say paletteLook)] "
vm '$Q closeAll; rm -rf ~/parity-sheet' > /dev/null
out+="file preview, "

start '$Q gamesToggle; sleep 2; wtype -M ctrl -k Return -m ctrl; sleep 1'
[[ $(say settingsSheet) == "Game settings" ]] || bad+="game-settings-did-not-open[$(say settingsSheet)] "
spot=$(say recallState)
click $((px + 300)) $((py + 215)); click $((px + 300)) $((py + 265)); click $((px + 127)) $((py + 215))
[[ $(say isOpen games) == true && $(say recallState) == "$spot" && $(say settingsSheet) == "Game settings" ]] || bad+="game-under-its-settings[$(say recallState)] "
click $((px + pw - 37)) $((py + 44))
[[ $(say settingsSheet) == "" && $(say isOpen games) == true && $(say recallState) == "$spot" ]] || bad+="game-settings-x[$(say settingsSheet) $(say recallState)] "
out+="game settings, "

start '$Q gamesToggle; sleep 2; wtype -k Tab; sleep 1; wtype -M ctrl -k Return -m ctrl; sleep 1'
[[ $(say settingsSheet) == "Clip settings" ]] || bad+="clip-settings-did-not-open[$(say settingsSheet)] "
click $((px + pw / 2)) $((py + ph - 120)); click $((px + pw / 2)) $((py + 50))
[[ $(say settingsSheet) == "Clip settings" ]] || bad+="clip-settings-closed-by-a-click "
click $((px + pw - 37)) $((py + 37))
[[ $(say settingsSheet) == "" ]] || bad+="clip-settings-x "
out+="clip settings, "

start '$Q captureToggle; sleep 1.5; wtype -M ctrl -k Return -m ctrl; sleep 1'
[[ $(say settingsSheet) == "Capture settings" ]] || bad+="capture-settings-did-not-open[$(say settingsSheet)] "
click $((px + pw / 2)) $((py + 60)); click $((px + pw / 3)) $((py + 100)); click $((px + 508)) $((py + 172))
[[ $(say settingsSheet) == "Capture settings" && $(say isOpen capture) == true ]] || bad+="capture-settings-closed-by-a-click "
click $((px + pw - 37)) $((py + 37))
[[ $(say settingsSheet) == "" ]] || bad+="capture-settings-x[$(say settingsSheet)] "
out+="capture settings, "

start '$Q musicToggle; sleep 1.5; wtype -M ctrl -k comma -m ctrl; sleep 1'
spot=$(say musicSpot)
click $((px + pw - 300)) $((py + ph - 52)); click $((px + 60)) $((py + ph - 120))
[[ $(say musicSpot) == "$spot" ]] || bad+="music-under-its-settings[$(say musicSpot)] "
out+="music settings, "

vm 'mkdir -p ~/Music/Fixture/Tones; torus-music index' > /dev/null 2>&1
start '$Q musicToggle; sleep 1.5; wtype tone; sleep 2; wtype -k Menu; sleep 0.6'
spot=$(say musicSpot)
click $((px + 60)) $((py + 110))
[[ $(say musicSpot) == "$spot" ]] || bad+="view-under-the-music-menu[$spot then $(say musicSpot)] "
out+="music menu, "

was=$(vm 'pactl get-default-sink')
ids=$(vm 'for i in a b c d e f g; do pactl load-module module-null-sink sink_name=click-$i sink_properties=device.description=Click-$i; done; pactl set-default-sink click-a' | tr '\n' ' ')
start '$Q dashboardToggle; sleep 1.2; for i in $(seq 45); do wtype -k Tab; sleep 0.12; [[ $($Q focusLabel | tail -1) == Click-a ]] && break; done; wtype -k Return; sleep 0.6'
IFS='|' read -r _ _ _ box < <(say pickerState)
IFS=, read -r bx by bw bh ly <<< "$box"
click $((px + ${bx:-0} + 80)) $((py + ${by:-0} + ${ly:-0} + 34 * 2 + 17))
[[ $(vm 'pactl get-default-sink') == click-c && $(say isOpen dashboard) == true && $(say pickerState) == closed ]] || bad+="click-in-the-list[$(vm 'pactl get-default-sink') $box] "
vm 'wtype -k Return; sleep 0.5' > /dev/null 2>&1
click $((px + pw - 60)) $((py + 60))
[[ $(say pickerState) == closed && $(say isOpen dashboard) == true ]] || bad+="click-beside-the-list "
vm "for i in $ids; do pactl unload-module \$i; done; pactl set-default-sink $was" > /dev/null 2>&1
out+="output list"

vm '$Q closeAll' > /dev/null
if [[ -z $bad ]]; then echo "sheet-click: ok nothing under an open sheet takes a click, and each X closes only its own ($out)"; else echo "sheet-click: FAIL $bad"; exit 1; fi
