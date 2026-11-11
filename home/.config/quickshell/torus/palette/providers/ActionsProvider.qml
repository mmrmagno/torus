import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services

Provider {
    id: root
    key: "actions"
    name: "Actions"
    glyph: "󰘳"
    help: "toggles, panels and tools of the shell"
    inAll: true

    readonly property var actions: [
        { id: "a:night", glyph: "󰖔", title: "Night light", sub: NightLight.on ? "on, turn off" : "off, turn on", act: () => NightLight.toggle() },
        { id: "a:nightauto", glyph: "󰖚", title: NightLight.auto ? "Stop the night light schedule" : "Night light at sunset", sub: NightLight.auto ? "on at " + NightLight.sunset + ", off at " + NightLight.sunrise : "on at " + NightLight.sunset + ", off at " + NightLight.sunrise + ", follows your weather location", keys: "night light schedule sunset sunrise auto", act: () => NightLight.setAuto(!NightLight.auto) },
        { id: "a:awake", glyph: Store.stayAwake ? "󰅶" : "󰾪", title: "Stay awake", sub: Store.stayAwake ? "on, the screens never sleep; turn off" : "off, keep the screens from sleeping", keys: "coffee caffeine idle sleep inhibit awake", act: () => Store.stayAwake = !Store.stayAwake },
        { id: "a:perf", glyph: "󰓅", title: "Power: performance", sub: PowerProfiles.profile === PowerProfile.Performance ? "active now" : "full speed, more heat and noise", keys: "power profile performance fast gaming", act: () => Island.setPower(PowerProfile.Performance) },
        { id: "a:balanced", glyph: "󰾅", title: "Power: balanced", sub: PowerProfiles.profile === PowerProfile.Balanced ? "active now" : "the everyday default", keys: "power profile balanced normal", act: () => Island.setPower(PowerProfile.Balanced) },
        { id: "a:saver", glyph: "󰾆", title: "Power: power saver", sub: PowerProfiles.profile === PowerProfile.PowerSaver ? "active now" : "quieter and cooler, saves battery", keys: "power profile saver battery quiet", act: () => Island.setPower(PowerProfile.PowerSaver) },
        { id: "a:dnd", glyph: "󰂛", title: "Do not disturb", sub: Store.dnd ? "on, turn off" : "off, turn on", act: () => Store.dnd = !Store.dnd },
        { id: "a:focus25", glyph: "󰔟", title: "Focus 25 minutes", sub: "timer in the island, notifications held", act: () => Focus.start(25) },
        { id: "a:focus50", glyph: "󰔟", title: "Focus 50 minutes", sub: "timer in the island, notifications held", act: () => Focus.start(50) },
        { id: "a:focusstop", glyph: "󰓛", title: "Stop focus", sub: "timer running", hidden: !Focus.running, act: () => Focus.stop() },
        { id: "a:living", glyph: "󰟪", title: "Living donut", sub: Store.livingDonut ? "on, turn off" : "off, turn on", act: () => Store.setLivingDonut(!Store.livingDonut) },
        { id: "a:processes", glyph: "󰍛", title: "Processes", sub: "CPU, memory and GPU per app, stop one", act: () => Store.setOpen("processes", true) },
        { id: "a:session", glyph: "󰑓", title: "Session restore", sub: "see what reopens after a reboot", act: () => Store.setOpen("session", true) },
        { id: "a:sessiontoggle", glyph: Session.on ? "󰜺" : "󰑓", title: Session.on ? "Turn session restore off" : "Turn session restore on", sub: Session.on ? "currently on: windows reopen after reboot" : "currently off: nothing reopens after reboot", act: () => Session.setOn(!Session.on) },
        { id: "a:meetnow", glyph: "󰤙", title: Meeting.active ? "End the meeting" : "Start a meeting now", sub: Meeting.active ? "notifications are held; Enter lets them through again" : "holds notifications until you end it here", keys: "meeting call dnd do not disturb hold notifications", act: () => Meeting.active ? Meeting.endNow() : Meeting.startNow() },
        { id: "a:meeting", glyph: "󰤙", title: "Meeting mode, automatic: " + (Meeting.autoOn ? "on" : "off"), sub: Meeting.autoOn ? "a call with mic plus camera or screen share holds notifications; Enter turns this off" : "Enter turns it on: a call with mic plus camera or screen share holds notifications", keys: "meeting call zoom teams dnd do not disturb camera auto", act: () => Meeting.setAuto(!Meeting.autoOn) },
        { id: "a:overlay", glyph: "󰄨", title: PerfOverlay.on ? "Hide the performance overlay" : "Show the performance overlay", sub: !PerfOverlay.installed ? "needs mangohud: sudo pacman -S mangohud, then log in again" : "fps, frame times, GPU and CPU in games; Shift_R+F12 in a game", keys: "mangohud fps frametime overlay hud performance gpu", act: () => PerfOverlay.toggle() },
        { id: "a:sounds", glyph: Store.sounds ? "󰕾" : "󰖁", title: "UI sounds: " + (Store.sounds ? "on" : "off"), sub: Store.sounds ? "panel clicks, lock and unlock chimes, screenshot shutter; Enter turns them off" : "Enter turns on a soft click for panels, lock chimes and a screenshot shutter", keys: "sound sounds audio click chime feedback", act: () => Store.setSounds(!Store.sounds) },
        { id: "a:dispsave", glyph: "󰍹", title: "Save display layout", sub: "for this set of screens; torus restores it whenever they are plugged in", keys: "monitor monitors screens displays layout profile dock", act: () => Quickshell.execDetached(["sh", "-c", "notify-send -a torus -i video-display 'Display layout' \"$(torus-displays save)\""]) },
        { id: "a:dispforget", glyph: "󰶐", title: "Forget this display layout", sub: "for this set of screens", keys: "monitor monitors screens displays layout profile forget", act: () => Quickshell.execDetached(["sh", "-c", "notify-send -a torus -i video-display 'Display layout' \"$(torus-displays forget)\""]) },
        { id: "a:game", glyph: "󰊴", title: "Game mode", sub: "animations, blur and donut off", act: () => Quickshell.execDetached(["torus-gamemode"]) },
        { id: "a:slideshow", glyph: "󰸉", title: Slideshow.on ? "Turn the wallpaper slideshow off" : "Turn the wallpaper slideshow on", sub: "every " + (Slideshow.minutes >= 60 ? Slideshow.minutes / 60 + " h" : Slideshow.minutes + " min"), act: () => Slideshow.set({ on: !Slideshow.on }) },
        { id: "a:wallnext", glyph: "󰸉", title: "Next wallpaper", sub: "", act: () => Store.stepWallpaper(1) },
        { id: "a:walldonut", glyph: "󰟪", title: "Donut wallpaper", sub: "", act: () => Store.setWallpaper("donut") },
        { id: "a:accent", glyph: "󰏘", title: "Theme", sub: "flavor, accent color, wallpaper, animations", keys: "accent color flavour flavor latte light dark mocha wallpaper animations", act: () => Store.setOpen("theme", true) },
        { id: "a:shot", glyph: "󰹑", title: "Screenshot area", sub: "", act: () => Quickshell.execDetached(["sh", "-c", "sleep 0.3; torus-shot s"]) },
        { id: "a:capture", glyph: "󰄀", title: "Capture studio", sub: "screenshots, recordings, recent captures (SUPER+Print)", keys: "screenshot record recording capture gallery video", act: () => Store.setOpen("capture", true) },
        { id: "a:record", glyph: "󰑋", title: "Record screen", sub: "start or stop", act: () => Quickshell.execDetached(["torus-record", "toggle"]) },
        { id: "a:ruler", glyph: "󰆾", title: "Measure an area", sub: "drag a box, copies its size as WxH (SUPER+Shift+M)", keys: "ruler measure size pixels dimensions", act: () => Quickshell.execDetached(["sh", "-c", "sleep 0.3; torus-ruler"]) },
        { id: "a:picker", glyph: "󰈊", title: "Color picker", sub: "pick from the screen, copies hex, # lists past picks", keys: "color color pick eyedropper hex", act: () => Quickshell.execDetached(["sh", "-c", "sleep 0.3; torus-pick"]) },
        { id: "a:clip", glyph: "󰅌", title: "Clipboard history", sub: "", act: () => Store.setOpen("clip", true) },
        { id: "a:dash", glyph: "󰕮", title: "Dashboard", sub: "", act: () => Store.setOpen("dashboard", true) },
        { id: "a:keys", glyph: "󰌌", title: "Keybind cheat sheet", sub: "", act: () => Store.setOpen("cheatsheet", true) },
        { id: "a:lock", glyph: "󰌾", title: "Lock screen", sub: "", act: () => Quickshell.execDetached(["torus-lock"]) },
        { id: "a:timer", glyph: "󰔛", title: "Timer or stopwatch", sub: "type t 5 for five minutes", keys: "timer stopwatch countdown alarm", keep: true, act: () => Commands.put("t ") },
        { id: "a:power", glyph: "󰐥", title: "Power menu", sub: "log out, reboot, power off", act: () => Store.setOpen("logout", true) }
    ]

    function results(term, scoped) {
        const out = []
        for (const a of actions)
            if (!a.hidden)
                out.push(Object.assign({ kind: "action", enter: "run" }, a))
        const f = Commands.win.focused
        if (f)
            out.push({ id: "a:window", kind: "action", keep: true, glyph: "󰖯", title: "Window: " + f.cls, sub: "move to workspace, float, pin, fullscreen, close, rules…", keys: "window move float tile pin fullscreen close center rule rules", enter: "open menu", act: () => Commands.win.menuFor(f, Commands.term) })
        return out
    }
}
