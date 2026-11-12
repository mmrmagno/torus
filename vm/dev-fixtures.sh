#!/usr/bin/env bash
# Runs inside the dev VM. Idempotent: everything vm/parity.sh expects, so `torus-vm freeze dev <image>` keeps it.
set -euo pipefail

sudo pacman -S --needed --noconfirm mangohud vulkan-tools vulkan-swrast wf-recorder podman python-numpy ffmpeg wtype > /dev/null 2>&1

mkdir -p ~/.config/hypr ~/.config/systemd/user
cat > ~/.config/hypr/monitors.lua <<'EOF'
hl.exec_cmd([[sh -c 'for i in $(seq 40); do hyprctl monitors -j > /dev/null 2>&1 && break; sleep 0.5; done; hyprctl monitors -j | grep -q "\"SIDE\"" || hyprctl output create headless SIDE']])
hl.monitor({ output = "SIDE", mode = "1920x1080", position = "1280x0", scale = 1, transform = 3 })
EOF

cat > ~/.config/systemd/user/torus-vm-awake.service <<'EOF'
[Unit]
Description=dev VM only: keep the torus shell from locking
After=torus-shell.service
PartOf=torus-shell.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for i in $(seq 30); do qs -c torus ipc call torus stayAwake true && exit 0; sleep 2; done'

[Install]
WantedBy=torus-shell.service
EOF
systemctl --user daemon-reload
systemctl --user enable torus-vm-awake.service > /dev/null 2>&1

podman image exists docker.io/library/busybox:1.37 || podman pull -q docker.io/library/busybox:1.37 > /dev/null

S=~/.local/share/Steam/steamapps
if [[ ! -f $S/appmanifest_620.acf ]]; then
  mkdir -p "$S/common/Portal 2"
  printf '"AppState"\n{\n\t"appid"\t\t"620"\n\t"name"\t\t"Portal 2"\n\t"installdir"\t\t"Portal 2"\n\t"LastPlayed"\t\t"1762800000"\n}\n' > "$S/appmanifest_620.acf"
fi
echo "dev fixtures: ok"
