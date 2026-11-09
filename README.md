# torus

My own Arch + Hyprland setup: Catppuccin Mocha everywhere, marc-os branding, and the spinning donut from
the About page of marc-os.com as its signature.

![The torus desktop with the spinning ASCII donut](screenshots/desktop.webp)

## Gallery

| | |
|:---:|:---:|
| ![Dashboard with weather, system stats, sound mixer and calendar](screenshots/dashboard.webp) | ![Command palette on SUPER+Space](screenshots/palette.webp) |
| The dashboard: weather, stats, a sound mixer per app, calendar | SUPER+Space: apps, windows, actions, maths, files, notes, passwords |
| ![Grouped notifications with media controls](screenshots/notifications.webp) | ![Lock screen with the donut and now playing](screenshots/lock.webp) |
| Notifications, grouped per app, repeats folded into one | The lock screen, with what is playing right under the password |
| ![An ASCII X-wing as the wallpaper](screenshots/xwing.webp) | ![fastfetch with the donut logo](screenshots/fetch.webp) |
| An X-wing, because why not | fastfetch, with a donut that spins for a second |
| ![Alt-tab with live previews](screenshots/alttab.webp) | ![Keybind cheat sheet with search](screenshots/cheatsheet.webp) |
| Alt-tab with live previews | A cheat sheet of every bind, searchable |
| ![Update centre with Arch news](screenshots/updates.webp) | ![The login screen](screenshots/login.webp) |
| Updates, with the Arch news that matters before you upgrade | The login screen, same donut |

The small things:

![The island showing the song and the current lyric line](screenshots/island.webp)
![After a screenshot, the island offers edit, text, folder and delete](screenshots/screenshot-island.webp)

| | |
|:---:|:---:|
| ![CPU card on hover](screenshots/hover-card.webp) | ![Wi-Fi and Bluetooth panel](screenshots/network.webp) |
| Hover the bar for the details | Wi-Fi and Bluetooth without leaving the bar |

## Why

I ran HyDE for a long time. It is good, but most of my desktop lived in files that get overwritten on
every update, and one migration quietly took my window rules with it. I want a setup I own end to end.

## What it does

The donut
- Drawn on the GPU, synced to each monitor, and it pauses when a game is fullscreen.
- Its colour follows the time of day and the album art of whatever is playing.
- The same donut in fastfetch, GRUB, Plymouth, the login screen and the lock screen. An X-wing if I want a change.

The shell, built on Quickshell
- A bar with hover cards for CPU, memory and GPU, and tooltips on everything.
- A dynamic island for music with live lyrics, volume, notifications, recording, a focus timer and screenshots.
- A dashboard with weather, a mixer per app, monitor brightness over DDC, and my Google calendar.
- Notifications grouped per app, repeats folded into one, quiet hours from midnight to six.
- A clipboard history with pins that survive a wipe.
- Wi-Fi, Bluetooth and an update centre with Arch news, all from the bar.
- A local AI sidebar on Ollama.

SUPER+Space
- Apps, open windows and quick actions in one box, ranked by what I use.
- `=` maths, `/` files, `?` my notes, `!` ask the AI, `:` emoji, `n ` past notifications.
- `p ` Proton Pass: pick an item, copy one field, the clipboard clears itself after 30 seconds.
- `rule` on any window: always float it, pin it to a workspace or a monitor, or keep the mouse inside it in fullscreen games.

The rest
- My apps come back on their workspaces after a reboot, kitty in the same folders.
- One accent picker that every app follows, on top of Catppuccin Mocha.
- Every keybind I had on HyDE, checked by a test in a VM.

## Keys I use the most

| Keys | What |
|---|---|
| SUPER+Space | command palette |
| SUPER+A | apps |
| SUPER+V | clipboard |
| SUPER+O | overview, then a number to jump |
| SUPER+/ | cheat sheet |
| SUPER+F12 | focus timer |
| SUPER+P | screenshot an area |
| SUPER+L | lock |

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
`vm/parity.sh` checks every feature in a running session, and `vm/cutover-test.sh` does the cutover and the
rollback on a copy of my HyDE setup, with Secure Boot on.
