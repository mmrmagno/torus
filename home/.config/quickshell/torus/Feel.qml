pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var defaults: ({
        "speed": 1,
        "reduceMotion": false,
        "stay": ["dashboard"],
        "followDelay": 400,
        "soundVolume": 1,
        "soundsOff": [],
        "islandOff": [],
        "islandSeconds": 1.6,
        "textScale": 1,
        "radius": 1,
        "glass": 1
    })
    readonly property var panels: ["dashboard", "network", "updates", "center", "theme", "capture", "session", "ocr", "processes"]
    readonly property var soundEvents: ["open", "lock", "notify", "device", "tick", "record", "delete", "error"]
    readonly property var islandEvents: ["music", "volume", "notifications", "devices", "battery", "meeting"]
    property var s: defaults

    readonly property real speed: Math.max(0.5, Math.min(1.5, num("speed")))
    readonly property bool reduceMotion: s.reduceMotion === true
    readonly property int followDelay: Math.max(0, Math.min(2000, num("followDelay")))
    readonly property real soundVolume: Math.max(0, Math.min(1.5, num("soundVolume")))
    readonly property real islandSeconds: Math.max(0.8, Math.min(6, num("islandSeconds")))
    readonly property real textScale: Math.max(0.85, Math.min(1.3, num("textScale")))
    readonly property real radius: Math.max(0, Math.min(1.6, num("radius")))
    readonly property real glass: Math.max(0, Math.min(2, num("glass")))

    function num(k) {
        const v = Number(s[k])
        return isNaN(v) ? defaults[k] : v
    }

    function list(k) {
        return Array.isArray(s[k]) ? s[k] : defaults[k]
    }

    function stays(panel) {
        return list("stay").indexOf(panel) >= 0
    }

    function soundOn(ev) {
        return list("soundsOff").indexOf(soundGroup(ev)) < 0
    }

    function soundGroup(ev) {
        switch (ev) {
        case "unlock": return "lock"
        case "notify": case "critical": return "notify"
        case "device-in": case "device-out": case "plug": case "unplug": case "online": case "offline": return "device"
        case "record-start": case "record-stop": case "shot": return "record"
        default: return ev
        }
    }

    function islandOn(ev) {
        return list("islandOff").indexOf(ev) < 0
    }

    function set(k, v) {
        const n = Object.assign({}, s)
        n[k] = v
        s = n
        file.setText(JSON.stringify(n, null, 1) + "\n")
    }

    function toggleIn(k, item, on) {
        const l = list(k).filter(x => x !== item)
        if (on)
            l.push(item)
        set(k, l)
    }

    function reset() {
        s = defaults
        file.setText(JSON.stringify(defaults, null, 1) + "\n")
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/torus/feel.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.s = Object.assign({}, root.defaults, JSON.parse(text()))
            } catch (e) {
                root.s = root.defaults
            }
        }
    }
}
