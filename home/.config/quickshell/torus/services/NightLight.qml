pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool on: false
    property int temperature: 6000
    property int seen: -1
    readonly property int warm: 5500

    function refresh() {
        if (!query.running)
            query.running = true
    }

    function toggle() {
        const next = !root.on
        root.on = next
        Quickshell.execDetached(["hyprctl", "hyprsunset", next ? "temperature " + root.warm : "identity"])
        if (next) {
            root.temperature = root.warm
            root.seen = root.warm
        }
        settle.restart()
    }

    Process {
        id: query
        command: ["hyprctl", "hyprsunset", "temperature"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text)
                if (n > 0 && n !== root.seen) {
                    root.seen = n
                    root.temperature = n
                    root.on = n < 6000
                }
            }
        }
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
