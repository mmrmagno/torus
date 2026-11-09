pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var levels: ({})
    property bool available: false
    property var pending: ({})

    function refresh() {
        if (!list.running)
            list.running = true
    }

    function set(monitor, value) {
        const l = Object.assign({}, levels)
        l[monitor] = Math.round(value)
        levels = l
        const p = Object.assign({}, pending)
        p[monitor] = Math.round(value)
        pending = p
        flush.restart()
    }

    Timer {
        id: flush
        interval: 180
        onTriggered: {
            for (const m in root.pending)
                Quickshell.execDetached(["torus-bright", "set", m, String(root.pending[m])])
            root.pending = {}
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
                root.levels = l
                root.available = Object.keys(l).length > 0
            }
        }
    }
}
