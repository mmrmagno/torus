# torus

My own Arch + Hyprland setup: Catppuccin everywhere, Mocha by default.

![The torus desktop with the spinning ASCII donut](screenshots/desktop.webp)

## Gallery

| | |
|:---:|:---:|
| ![Dashboard with weather, system stats, sound mixer and calendar](screenshots/dashboard.webp) | ![Command palette on SUPER+Space](screenshots/palette.webp) |
| The dashboard: weather, stats, a sound mixer per app, calendar | SUPER+Space: apps, windows, actions, calc, files, notes, passwords |
| ![Grouped notifications with media controls](screenshots/notifications.webp) | ![Lock screen with the donut and now playing](screenshots/lock.webp) |
| Notifications, grouped per app and per conversation, repeats folded into one | The lock screen, with what is playing right under the password |
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
- SUPER+Space: one box for apps, windows, math, paths and links, no prefixes to remember. Tab steps through the scopes, `?` lists them, and Proton Pass only answers in its own.
- `d` in SUPER+Space: every git repo under `~/dev` with its branch and how much is dirty. Enter opens a terminal there, Ctrl+Enter nvim, Alt+Enter the repo page.
- Alt+Shift+Enter on a project in SUPER+Space opens its whole workspace: nvim, a terminal and the repo page side by side (or what the repo's `.torus-layout` lists: `nvim`, `term`, `lazygit`, `repo`, `url ...`, nothing else runs). Containers group by compose project, with a restart for the whole project.
- `s` in SUPER+Space: the hosts from `~/.ssh/config`, Enter connects in kitty, the ones I use most come first.
- A dev pill in the bar that only shows up when it has something: my dev servers (hover for port, folder and command, click opens, the square stops), running Docker or podman containers (logs, restart, stop, also `c` in SUPER+Space) and GitHub.
- A controller pill with its battery, only while a controller is connected.
- SUPER+Shift+G: my Steam games as covers, last played first, with playtime; type to filter, Enter plays.
- Games get their own replay buffer: it starts with the game on its screen, SUPER+Alt+R files a clip under `~/Videos/Clips/<Game>` and the island says so. In SUPER+Shift+G, Tab shows the clips (Enter plays, Del trashes, Ctrl+C copies the file for Discord) and then the game's own settings (overlay, power profile, buffer and its length, held notifications). When the game closes, the island sums up the session: time, average FPS, 1 % low, GPU heat, clips.
- SUPER+Shift+M measures an area: drag a box and its size lands in the clipboard as `WxH`.
- Optional UI sounds (off unless I turn them on in SUPER+Space): a soft click for panels, chimes on lock and unlock, a shutter for screenshots, start and stop for recordings, a trash sound when I delete something, a tick for volume, brightness and mic, network, charger and USB device chimes (the island names the keyboard, mouse or drive), an error tone for a wrong password, and a ding for notifications from apps that have no sound of their own.
- Display layouts per set of screens: arrange them once, "Save display layout" in SUPER+Space (type "display" to see the saved ones), and they come back that way whenever that set is plugged in (desk at work, desk at home, laptop alone).
- Face unlock on the laptop (Howdy, IR camera): the lock looks for me as soon as it locks, a key retries, the password always works. `sudo torus-howdy setup --sudo` turns it on for sudo too, `off` puts everything back.
- When Howdy looks for my face (the lock, or sudo in a terminal) the island shows a scanning ring, draws a check when it knows me and turns red when it does not.
- Touchpad: three fingers sideways switch workspaces, four fingers up open the overview, down the dashboard.
- kitty tells me when a command over 30 s finishes while I am in another window, with its exit status.
- A GitHub chip that only shows up when something wants me: review requests, my pull requests with red CI, a failing main branch. `gh ` in SUPER+Space lists them all.
- After a `git push` in the terminal, torus follows the Actions run for that commit and tells me when CI passed or failed (green or red on the island, Open goes to the run), quiet during DND and games like every notification.
- SUPER+` drops down a terminal in the project of the window I am in, one per project, kept around when hidden.
- Meeting mode: when an app has my mic and my camera or a screen share, notifications wait and the slideshow pauses until the call ends.
- Calendar events with a Meet, Teams or Zoom link offer Join two minutes before; joining opens the call and holds my notifications at once, until the call lets go of the mic.
- A performance overlay for games (MangoHud in my colors), on and off from SUPER+Space; the GPU chip shows load and heat while I play.
- The donut drawn on the GPU, tinted by the time of day and the album art. Or an X-wing.
- With "living donut" on, the donut spins faster when the CPU works, wobbles when a notification lands and breathes when the machine idles; the X-wing banks toward the workspace I switch to.
- Panels grow and shrink inside a window that never moves, so nothing jumps when their content loads, and a click next to a panel or between notification cards reaches whatever is underneath.
- The island cross-fades: when music gives way to the volume, a notification or a recording, the old face slides out while the new one fades in and the pill morphs to its new size.
- One-time codes in notifications get a Copy button on the card and a row in SUPER+Space for two minutes; the copy is marked sensitive so it never lands in the clipboard history, clears itself after 90 s, and the notification history keeps the code masked.
- `!` in SUPER+Space with nothing typed explains the text I selected, or the last command that failed in my terminal, with the local model; after being away it offers to summarize what I missed. The model is picked to fit the machine, and the laptop can use the desktop's ollama (`"remote"` in `~/.config/torus/ai.json`).
- A clipboard with pins (Tab steps through text, links, images, colors and code, Del removes, Ctrl+P pins), a mixer per app, Wi-Fi and Bluetooth, updates with Arch news and what is new in torus since my installed commit (Update torus pulls and reinstalls), my calendar.
- On workday mornings and evenings the island warns me when rain starts within the hour, with how much (Open-Meteo, once per window).
- My next trains home or to work at the bottom of the dashboard, and a heads-up at 18:30 on workdays. Two addresses in `~/.config/torus/commute.json` (`"evening"` and `"morning"` set or turn off the heads-ups), timetable from [transport.opendata.ch](https://transport.opendata.ch).
- When transport.opendata.ch is down, the trains still come, from the official OJP timetable (a free key from opentransportdata.swiss in `~/.config/torus/ojp.key`, mode 600); the card says "backup timetable".
- Window rules from SUPER+Space, and my apps back on their workspaces after a reboot.
- The dashboard and the notification center close the way they open: the same key, Esc, or a click anywhere outside, also when the touchpad pointer has wandered off. `torus doctor --parity` proves a machine runs torus cleanly (panels, keys, Esc, a sound reaching PipeWire, no QML warnings).
- On battery the laptop calms down by itself: the wallpaper rests, a fast panel drops to 60 Hz, blur gets lighter and the clock stops ticking seconds (a leaf in the bar says so). `"full"` in `~/.local/state/torus/battery-mode` keeps it at full power.
- The theme studio's Feel section sets everything that moves or makes noise: animation speed and reduce motion, which panels follow focus and how fast, every UI sound on its own with a play button and one volume, what the island shows and for how long, text size, corners and glass.
- The dev VM can run the whole parity suite every night at 04:00 when I am not gaming (`systemctl --user enable --now torus-parity-nightly.timer`), and `torus doctor` tells me how it went.
- SUPER+H: my homelab at a glance, read only: nodes with their load, Flux, unhealthy pods, every app by its route, the Tailscale routers, whether AMT answers (Console and Web buttons, no passwords in torus), the last etcd backup. A red chip shows up in the bar only when something is wrong.
- `torus doctor` checks the whole setup (`--fix` repairs the safe things, `--snapshot` saves evidence from a TTY), `torus ipc` lists and calls every shell action, and a small safe-mode bar takes over if the shell keeps crashing. A crash leaves its log in `~/.cache/torus/crashes`, starting with the QML warnings of the run that crashed, and tells me on the next start (`torus-crash last` opens it in nvim).
- One flavor (Mocha, Macchiato, Frappe, Latte) and one accent color that every app follows: `torus flavor latte`, `torus accent blue`.

## Keys I use the most

| Keys | What |
|---|---|
| SUPER+Space | command palette |
| SUPER+A | apps |
| SUPER+V | clipboard |
| SUPER+` | terminal in this project |
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
