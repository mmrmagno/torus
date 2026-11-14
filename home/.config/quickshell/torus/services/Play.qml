pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property var session: ({})
    property var last: ({})
    readonly property bool active: session.start !== undefined
    readonly property bool buffering: active && session.replay === true
    readonly property bool hold: !active || session.hold !== "off"

    property string shownId: ""
    property var shown: ({})
    property var clips: []

    function load(appid) {
        shownId = String(appid)
        shown = {}
        clips = []
        settingsProc.running = false
        settingsProc.running = true
        clipsProc.running = false
        clipsProc.running = true
    }

    function set(appid, key, value) {
        const n = Object.assign({}, shown)
        n[key] = value
        shown = n
        Quickshell.execDetached(["torus-play", "set", String(appid), key, String(value)])
    }

    FileView {
        path: Store.stateDir + "/play-session.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.session = JSON.parse(text()) || {}
            } catch (e) {
                root.session = {}
            }
        }
        onLoadFailed: root.session = {}
    }

    FileView {
        path: Store.stateDir + "/play-last.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.last = JSON.parse(text()) || {}
            } catch (e) {
                root.last = {}
            }
        }
    }

    Process {
        id: settingsProc
        command: ["torus-play", "settings", root.shownId]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.shown = JSON.parse(text)
                } catch (e) {
                    root.shown = {}
                }
            }
        }
    }

    Process {
        id: clipsProc
        command: ["torus-play", "clips", root.shownId]
        stdout: StdioCollector {
            onStreamFinished: root.clips = text.split("\n").filter(l => l).map(l => {
                const f = l.split("\t")
                return { path: f[0], at: Number(f[1]) || 0, thumb: f[2] || "", size: Number(f[3]) || 0, auto: f[4] || "", fav: f[5] === "1" }
            })
        }
    }
}
