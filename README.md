# torus

My own Arch + Hyprland setup: Catppuccin everywhere, Mocha by default.

![The torus desktop with the spinning ASCII donut](screenshots/desktop.webp)

## Gallery

| | |
|:---:|:---:|
| ![Dashboard with weather, system stats, sound mixer and calendar](screenshots/dashboard.webp) | ![Command palette on SUPER+Space](screenshots/palette.webp) |
| The dashboard: weather, stats, a sound mixer per app, calendar | SUPER+Space: apps, windows, actions, calc, files, notes, passwords |
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

I ran [HyDE](https://github.com/HyDE-Project/HyDE) for a long time. It is good, but most of my desktop
lived in files that get overwritten on every update, and one migration quietly took my window rules
with it. I want a setup I own end to end.

## What it does

- A Quickshell shell: bar, dashboard, notifications, a dynamic island for music and alerts, lock screen.
- SUPER+Space: apps, windows, calc, files, notes, emoji and Proton Pass in one box.
- The donut drawn on the GPU, tinted by the time of day and the album art. Or an X-wing.
- A clipboard with pins, a mixer per app, Wi-Fi and Bluetooth, updates with Arch news, my calendar.
- My next trains home or to work at the bottom of the dashboard, and a heads-up at 18:30 on workdays. Two addresses in `~/.config/torus/commute.json` (`"evening"` and `"morning"` set or turn off the heads-ups), timetable from [transport.opendata.ch](https://transport.opendata.ch).
- Window rules from SUPER+Space, and my apps back on their workspaces after a reboot.
- One flavor (Mocha, Macchiato, Frappe, Latte) and one accent color that every app follows: `torus flavor latte`, `torus accent blue`.

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
