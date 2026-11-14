pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    property var levels: ({})
    property bool available: false
    property var pending: ({})
    property string writing: ""
    property int writes: 0
    property bool linked: false
    property bool nightDim: false
    property int dimmed: 0
    readonly property int dimStep: 15
    readonly property string linkFile: Store.stateDir + "/ddc-link"
    readonly property string dimFile: Store.stateDir + "/ddc-night-dim"
    readonly property string dimmedFile: Store.stateDir + "/ddc-dimmed"

    function refresh() {
        if (!list.running)
            list.running = true
    }

    function set(monitor, value) {
        const v = Math.max(0, Math.min(100, Math.round(value)))
        const targets = linked ? Object.keys(levels) : [monitor]
        const l = Object.assign({}, levels)
        const p = Object.assign({}, pending)
        for (const m of targets) {
            l[m] = v
            p[m] = v
        }
        levels = l
        pending = p
        settle.restart()
    }

    function step(dir) {
        const mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        if (levels[mon] === undefined) {
            refresh()
            return false
        }
        const v = Math.max(0, Math.min(100, levels[mon] + (dir === "up" ? 5 : -5)))
        set(mon, v)
        Island.flash("osd", { icon: "󰃟", label: (linked ? "both " : "") + v + "%", value: v / 100, cat: "brightness" }, 1600)
        Store.sound("tick")
        return true
    }

    property var taken: ({})

    function shift(delta) {
        const t = Object.assign({}, taken)
        for (const m of Object.keys(levels)) {
            const l = Object.assign({}, levels)
            const p = Object.assign({}, pending)
            const d = delta > 0 && t[m] !== undefined ? t[m] : delta
            l[m] = Math.max(0, Math.min(100, levels[m] + d))
            if (delta < 0)
                t[m] = levels[m] - l[m]
            else
                delete t[m]
            p[m] = l[m]
            levels = l
            pending = p
        }
        taken = t
        settle.restart()
    }

    function setLinked(on) {
        linked = on
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && echo \"$2\" > \"$1\"", "sh", linkFile, on ? "on" : "off"])
    }

    function setNightDim(on) {
        nightDim = on
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && echo \"$2\" > \"$1\"", "sh", dimFile, on ? "on" : "off"])
        applyNight()
    }

    function applyNight() {
        const want = nightDim && NightLight.on && available ? dimStep : 0
        if (want !== dimmed) {
            shift(dimmed - want)
            dimmed = want
            Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && echo \"$2\" > \"$1\"", "sh", dimmedFile, String(want)])
        }
    }

    function pump() {
        if (writer.running)
            return
        const keys = Object.keys(pending)
        if (!keys.length)
            return
        const m = keys[0]
        const p = Object.assign({}, pending)
        const v = p[m]
        delete p[m]
        pending = p
        writing = m
        writes++
        writer.command = ["torus-bright", "set", m, String(v)]
        writer.running = true
    }

    Connections {
        target: NightLight
        function onOnChanged() {
            root.applyNight()
        }
    }

    Timer {
        id: settle
        interval: 250
        onTriggered: root.pump()
    }

    Process {
        id: writer
        onExited: {
            root.writing = ""
            root.pump()
        }
    }

    Process {
        id: list
        command: ["torus-bright", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = {}
                for (const line of text.split("\n")) {
                    const f = line.trim().split(/\s+/)
                    if (f.length === 2 && f[1] !== "")
                        l[f[0]] = Number(f[1])
                }
                for (const m in root.pending)
                    if (l[m] !== undefined)
                        l[m] = root.pending[m]
                root.levels = l
                root.available = Object.keys(l).length > 0
                root.applyNight()
            }
        }
    }

    FileView {
        path: root.linkFile
        printErrors: false
        onLoaded: root.linked = text().trim() === "on"
    }

    FileView {
        path: root.dimmedFile
        printErrors: false
        blockLoading: true
        onLoaded: root.dimmed = Number(text().trim()) || 0
    }

    FileView {
        path: root.dimFile
        printErrors: false
        onLoaded: root.nightDim = text().trim() === "on"
    }
}
