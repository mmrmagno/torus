pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Qt.labs.folderlistmodel

Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/torus"
    readonly property var barPresets: ["full", "compact"]
    property string barPreset: "full"
    property bool barHidden: false
    readonly property int barHeight: barHidden ? 0 : (barPreset === "compact" ? 24 : 28)
    readonly property int barGap: barHidden ? 6 : barHeight + (barPreset === "compact" ? 3 : 4) + 8
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
    property bool dnd: false
    property bool osdVisible: false
    property bool gamemode: false
    property var altTabber: null
    property bool donutPaused: false
    property string wallpaper: "donut"
    property var frames: ({})
    readonly property var wallpapers: {
        const out = ["donut"]
        for (let i = 0; i < walls.count; i++)
            out.push("still:" + walls.get(i, "filePath"))
        return out
    }

    function reportFrames(screenName, n) {
        frames[screenName] = n
    }

    function setWallpaper(mode) {
        if (mode !== "donut" && !mode.startsWith("still:"))
            return
        wallpaper = mode
        wallFile.setText(mode + "\n")
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

    function setOpen(name, value) {
        const o = Object.assign({}, open)
        o[name] = value
        open = o
    }

    function isOpen(name) {
        return open[name] === true
    }

    function toggle(name) {
        setOpen(name, !isOpen(name))
    }

    function closeAll(except) {
        const o = {}
        if (except)
            o[except] = open[except] === true
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

    FolderListModel {
        id: walls
        folder: "file://" + Quickshell.env("HOME") + "/Pictures/wallpapers"
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    FileView {
        id: wallFile
        path: root.stateDir + "/wallpaper"
        blockLoading: true
        printErrors: false
        onLoaded: {
            const v = text().trim()
            if (v === "donut" || v.startsWith("still:"))
                root.wallpaper = v
        }
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
