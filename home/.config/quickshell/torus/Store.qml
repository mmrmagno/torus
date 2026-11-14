pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Qt.labs.folderlistmodel

Singleton {
    id: root

    PersistentProperties {
        id: kept
        reloadableId: "torus-store"
        property bool dnd: false
        property bool stayAwake: false
    }

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/torus"
    readonly property var barPresets: ["full", "compact"]
    property string barPreset: "full"
    property bool barHidden: false
    readonly property int barHeight: barHidden ? 0 : (barPreset === "compact" ? 24 : 28)
    readonly property int barGap: barHidden ? 6 : barHeight + (barPreset === "compact" ? 3 : 4) + 8
    readonly property int barReserved: barHidden ? 0 : barHeight + (barPreset === "compact" ? 3 : 4)

    function panelRoom(scr, margin) {
        return Math.floor((scr ? scr.height : 900) - barGap - barReserved - margin)
    }
    property var modules: ({})
    property var open: ({})
    readonly property var focusedScreen: {
        const m = Hyprland.focusedMonitor
        const list = Quickshell.screens
        for (let i = 0; i < list.length; i++)
            if (m && list[i].name === m.name)
                return list[i]
        return list.length > 0 ? list[0] : null
    }
    property int notifCount: 0
    property alias dnd: kept.dnd
    property bool osdVisible: false
    property bool gamemode: false
    property var altTabber: null
    property var rulerView: null
    property string rulerShot: ""
    property string pendingCut: ""
    property string rulerLast: ""
    property bool donutPaused: false
    property bool locked: false

    FileView {
        path: root.stateDir + "/sounds"
        blockLoading: true
        printErrors: false
        onLoaded: root.sounds = text().trim() === "on"
    }
    readonly property var widgetModes: ["landscape", "all", "off"]
    property string widgets: "landscape"
    property var widgetsOn: ({})
    property bool lockSecure: false
    property string polkitState: "none"
    property int cardsMade: 0
    property string wallpaper: "donut"
    property bool livingDonut: true
    property bool clockDate: true

    function focusWindow(t) {
        if (t && t.address)
            Hyprland.dispatch('hl.dsp.focus({ window = "address:0x' + t.address + '" })')
    }

    function setClockDate(on) {
        clockDate = on
        clockFile.setText(on ? "on\n" : "off\n")
    }

    function setLivingDonut(on) {
        livingDonut = on
        livingFile.setText(on ? "on\n" : "off\n")
    }
    property var frames: ({})
    readonly property var wallpapers: {
        const out = ["donut", "xwing"]
        for (let i = 0; i < walls.count; i++)
            out.push("still:" + walls.get(i, "filePath"))
        return out
    }

    property var life: ({})

    function reportLife(screenName, s) {
        const l = Object.assign({}, life)
        l[screenName] = s
        life = l
    }

    function reportFrames(screenName, n) {
        frames[screenName] = n
    }

    property var wallOf: ({})
    property bool breathing: false
    property bool matchAccent: true

    function wallFor(screenName) {
        return wallOf[screenName] || wallpaper
    }

    function setWallpaper(mode) {
        setWallpaperFor("", mode)
    }

    function setWallpaperFor(screenName, mode) {
        if (mode !== "donut" && mode !== "xwing" && !mode.startsWith("still:"))
            return
        const w = Object.assign({}, wallOf)
        if (screenName === "") {
            wallpaper = mode
            wallFile.setText(mode + "\n")
            for (const k in w)
                delete w[k]
        } else if (mode === wallpaper) {
            delete w[screenName]
        } else {
            w[screenName] = mode
        }
        wallOf = w
        wallScreensFile.setText(JSON.stringify(w))
        if (matchAccent && mode.startsWith("still:"))
            Quickshell.execDetached(["sh", "-c", "a=$(torus-wallcolor \"$1\") && torus accent \"$a\" > /dev/null", "torus-wallcolor", mode.slice(6)])
    }

    function setBreathing(on) {
        breathing = on
        breatheFile.setText(on ? "on\n" : "off\n")
    }

    function setMatchAccent(on) {
        matchAccent = on
        matchFile.setText(on ? "on\n" : "off\n")
    }

    function stepWallpaper(dir) {
        const list = wallpapers
        const i = Math.max(0, list.indexOf(wallpaper))
        setWallpaper(list[(i + dir + list.length) % list.length])
    }

    function registerModules(screenName, ids) {
        const m = Object.assign({}, modules)
        m[screenName] = ids
        modules = m
    }

    property var closedAt: ({})

    property string themeSection: ""
    property alias stayAwake: kept.stayAwake
    property string focusLabel: ""
    property bool widgetsQuiet: false
    property string mixerShown: ""
    property var screenOf: ({})
    property var pendingScreen: null

    readonly property var stayPut: ["palette", "clip", "ai", "logout", "cheatsheet", "overview", "games", "homelab"].concat(Feel.list("stay"))
    readonly property var exclusive: ["palette", "clip", "ai", "logout", "cheatsheet", "overview", "games"]
    property var activeScreen: null
    property bool moving: false

    function screenFor(name) {
        return screenOf[name] || activeScreen || focusedScreen
    }

    onFocusedScreenChanged: {
        if (Object.keys(open).some(k => open[k] === true && stayPut.indexOf(k) < 0))
            dwell.restart()
        else
            activeScreen = focusedScreen
    }

    Timer {
        id: dwell
        interval: Math.max(1, Feel.followDelay)
        onTriggered: root.follow()
    }

    function follow() {
        if (activeScreen === focusedScreen)
            return
        const any = Object.keys(open).some(k => open[k] === true && stayPut.indexOf(k) < 0)
        if (!any || !activeScreen || Theme.motion === 0) {
            activeScreen = focusedScreen
            return
        }
        const so = {}
        for (const k in screenOf)
            if (stayPut.indexOf(k) >= 0)
                so[k] = screenOf[k]
        screenOf = so
        moving = true
        moveTimer.restart()
    }

    Timer {
        id: moveTimer
        interval: Theme.durFast + 30
        onTriggered: {
            root.activeScreen = root.focusedScreen
            root.moving = false
        }
    }

    function toggleOn(name, scr) {
        pendingScreen = scr || null
        toggle(name)
        pendingScreen = null
    }

    property bool sounds: false

    property var soundAt: ({})

    property string soundAsked: ""

    function sound(ev) {
        soundAsked = ev
        if (!sounds || !Feel.soundOn(ev))
            return
        const now = Date.now()
        if (now - (soundAt[ev] || 0) < (ev === "tick" ? 110 : 400))
            return
        const a = Object.assign({}, soundAt)
        a[ev] = now
        soundAt = a
        Quickshell.execDetached(["torus-sound", "play", ev, String(Feel.soundVolume)])
    }

    signal trashed(string name, int count)
    signal restored()

    function trash(path) {
        trashMany([path])
    }

    function trashMany(paths) {
        const list = paths.filter(p => p)
        if (list.length === 0)
            return
        Quickshell.execDetached(["torus-trash", "put"].concat(list))
        sound("delete")
        trashed(list[0].split("/").pop(), list.length)
    }

    function setSounds(on) {
        sounds = on
        Quickshell.execDetached(["torus-sound", on ? "on" : "off"])
        if (on)
            Quickshell.execDetached(["sh", "-c", "sleep 0.2; torus-sound play unlock"])
    }

    function setOpen(name, value) {
        if (value && open[name] !== true && sounds)
            sound("open")
        if (value && open[name] !== true) {
            const so = Object.assign({}, screenOf)
            if (pendingScreen)
                so[name] = pendingScreen
            else if (stayPut.indexOf(name) >= 0)
                so[name] = focusedScreen
            else
                delete so[name]
            screenOf = so
        }
        if (!value && open[name] === true) {
            const c = Object.assign({}, closedAt)
            c[name] = Date.now()
            closedAt = c
        }
        const o = Object.assign({}, open)
        o[name] = value
        if (value && exclusive.indexOf(name) >= 0) {
            const c = Object.assign({}, closedAt)
            for (const k of exclusive) {
                if (k !== name && o[k] === true) {
                    o[k] = false
                    c[k] = Date.now()
                }
            }
            closedAt = c
        }
        open = o
    }

    property string captureSel: ""
    property string clipsInfo: ""
    property string look: ""
    property string sheetTitle: ""
    property bool ocrEmpty: false
    readonly property bool popupsRest: isOpen("center") || isOpen("network") || isOpen("updates") || isOpen("session") || isOpen("ai")

    function isOpen(name) {
        return open[name] === true
    }

    function toggle(name) {
        if (!isOpen(name) && Date.now() - (closedAt[name] || 0) < 250)
            return
        setOpen(name, !isOpen(name))
    }

    function closeAll(except) {
        const o = {}
        const c = Object.assign({}, closedAt)
        for (const k in open)
            if (open[k] === true && k !== except)
                c[k] = Date.now()
        if (except)
            o[except] = open[except] === true
        closedAt = c
        open = o
    }

    function setBarPreset(name) {
        let next = name
        const i = barPresets.indexOf(barPreset)
        if (name === "next")
            next = barPresets[(i + 1) % barPresets.length]
        else if (name === "prev")
            next = barPresets[(i - 1 + barPresets.length) % barPresets.length]
        if (barPresets.indexOf(next) < 0)
            return
        barPreset = next
        presetFile.setText(next + "\n")
    }

    function setWidgets(name) {
        let next = name
        if (name === "next")
            next = widgetModes[(widgetModes.indexOf(widgets) + 1) % widgetModes.length]
        if (widgetModes.indexOf(next) < 0)
            return
        widgets = next
        widgetsFile.setText(next + "\n")
    }

    function reportWidgets(screenName, on) {
        const w = Object.assign({}, widgetsOn)
        w[screenName] = on
        widgetsOn = w
    }

    FileView {
        id: widgetsFile
        path: root.stateDir + "/widgets"
        blockLoading: true
        printErrors: false
        onLoaded: {
            const v = text().trim()
            if (root.widgetModes.indexOf(v) >= 0)
                root.widgets = v
        }
    }

    FolderListModel {
        id: walls
        folder: "file://" + Quickshell.env("HOME") + "/Pictures/wallpapers"
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    FileView {
        id: clockFile
        path: root.stateDir + "/clock-date"
        blockLoading: true
        printErrors: false
        onLoaded: root.clockDate = text().trim() !== "off"
    }

    FileView {
        id: livingFile
        path: root.stateDir + "/living-donut"
        blockLoading: true
        printErrors: false
        onLoaded: root.livingDonut = text().trim() !== "off"
    }

    FileView {
        id: wallFile
        path: root.stateDir + "/wallpaper"
        blockLoading: true
        printErrors: false
        onLoaded: {
            const v = text().trim()
            if (v === "donut" || v === "xwing" || v.startsWith("still:"))
                root.wallpaper = v
        }
    }

    FileView {
        id: wallScreensFile
        path: root.stateDir + "/wallpaper-screens.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.wallOf = JSON.parse(text())
            } catch (e) {
                root.wallOf = {}
            }
        }
    }

    FileView {
        path: root.stateDir + "/gamemode"
        blockLoading: true
        printErrors: false
        onLoaded: root.gamemode = ["on", "auto"].indexOf(text().trim()) >= 0
    }

    FileView {
        id: breatheFile
        path: root.stateDir + "/wall-breathe"
        blockLoading: true
        printErrors: false
        onLoaded: root.breathing = text().trim() === "on"
    }

    FileView {
        id: matchFile
        path: root.stateDir + "/wall-accent"
        blockLoading: true
        printErrors: false
        onLoaded: root.matchAccent = text().trim() !== "off"
    }

    FileView {
        id: presetFile
        path: root.stateDir + "/bar"
        blockLoading: true
        printErrors: false
        onLoaded: {
            const v = text().trim()
            if (root.barPresets.indexOf(v) >= 0)
                root.barPreset = v
        }
    }
}
