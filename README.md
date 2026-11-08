# torus

My own Arch + Hyprland setup: Catppuccin Mocha everywhere, marc-os branding, and the spinning donut from
the About page of marc-os.com as its signature.

## Why

I ran HyDE for a long time. It is good, but most of my desktop lived in files that get overwritten on
every update, and one migration quietly took my window rules with it. I want a setup I own end to end.

## What it does

- A Quickshell shell: bar, dashboard, notifications, a dynamic island for music, volume and alerts, a lock
  screen, a clipboard panel, a local AI sidebar on Ollama, and desktop widgets.
- The donut as the wallpaper on every screen, in fastfetch, in GRUB, in Plymouth and on the login screen.
- One accent picker that every app follows, on top of Catppuccin Mocha.
- Every keybind I had on HyDE, checked by a test in a VM.

## Install

Make a fresh backup first, then cut over from HyDE:

```sh
sudo backup/backup.sh
./cutover.sh
```

`cutover.sh` refuses to run without a verified backup from the last 24 hours, and checks that the repo
packages download and every EFI file is signed before it touches anything. It moves HyDE's files into
`~/.local/share/torus/attic` instead of deleting them, links this repo into my home, and themes the boot
chain without ever running `grub-install`. Reboot when it says so.

## Rollback

```sh
./rollback.sh
```

It puts the original GRUB, mkinitcpio and SDDM files back byte for byte, then restores the backup the
cutover recorded: files, packages and services. Anything it overwrites in my home goes to
`~/.local/share/torus/attic` first, so nothing I changed on torus is lost. Reboot and HyDE is back.

## Tests

`tests/run.sh` runs the script tests. `vm/rice-test.sh` installs everything on a fresh VM and checks it,
and `vm/cutover-test.sh` does the cutover and the rollback on a copy of my HyDE setup, with Secure Boot on.
