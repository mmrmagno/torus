pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property bool on: false
    property int minutes: 30
    property bool shuffle: true
    property bool shaders: true
    property bool perScreen: false
    readonly property var choices: [5, 15, 30, 60, 180, 1440]
    readonly property bool paused: Store.locked || Fullscreen.any || Meeting.active

    function set(patch) {
        const d = Object.assign({ on: on, minutes: minutes, shuffle: shuffle, shaders: shaders, perScreen: perScreen }, patch)
        on = d.on
        minutes = d.minutes
        shuffle = d.shuffle
        shaders = d.shaders
        perScreen = d.perScreen
        file.setText(JSON.stringify(d) + "\n")
    }

    function pick(current, taken) {
        const pool = Store.wallpapers.filter(w => (shaders || w.startsWith("still:")) && w !== current && taken.indexOf(w) < 0)
        if (pool.length === 0)
            return ""
        if (shuffle)
            return pool[Math.floor(Math.random() * pool.length)]
        const all = Store.wallpapers.filter(w => shaders || w.startsWith("still:"))
        const i = all.indexOf(current)
        for (let k = 1; k <= all.length; k++) {
            const next = all[(i + k) % all.length]
            if (next !== current && taken.indexOf(next) < 0)
                return next
        }
        return ""
    }

    function next() {
        if (!perScreen) {
            const w = pick(Store.wallpaper, [])
            if (w !== "")
                Store.setWallpaper(w)
            return
        }
        const taken = []
        for (const s of Quickshell.screens) {
            const w = pick(Store.wallFor(s.name), taken)
            if (w === "")
                continue
            taken.push(w)
            Store.setWallpaperFor(s.name, w)
        }
    }

    Timer {
        interval: Math.max(1, root.minutes) * 60000
        repeat: true
        running: root.on && !root.paused
        onTriggered: root.next()
    }

    FileView {
        id: file
        path: Store.stateDir + "/wall-slideshow.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text())
                root.on = d.on === true
                root.minutes = root.choices.indexOf(d.minutes) >= 0 ? d.minutes : 30
                root.shuffle = d.shuffle !== false
                root.shaders = d.shaders !== false
                root.perScreen = d.perScreen === true
            } catch (e) {}
        }
    }
}
