#!/usr/bin/env bash
set -euo pipefail
exec > /var/log/torus-firstboot.log 2>&1

echo 'mmr ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/10-mmr-vm
chmod 440 /etc/sudoers.d/10-mmr-vm
sbctl create-keys
sbctl enroll-keys -m
grub-install --target=x86_64-efi --efi-directory=/boot --removable --modules="tpm" --disable-shim-lock
grub-mkconfig -o /boot/grub/grub.cfg
sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
sbctl sign -s /boot/vmlinuz-linux
sbctl verify
systemctl disable torus-firstboot.service
systemctl poweroff
