pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    property real level: 1
    readonly property bool on: level > 1.01

    function show(z) {
        root.level = Math.max(1, Number(z) || 1)
    }

    function reset() {
        root.level = 1
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ cursor = { zoom_factor = 1 } })"])
    }

    Component.onCompleted: probe.running = true

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded" && !probe.running)
                probe.running = true
        }
    }

    Connections {
        target: Store
        function onLockedChanged() {
            if (Store.locked)
                root.reset()
        }
    }

    Process {
        id: probe
        command: ["hyprctl", "-j", "getoption", "cursor:zoom_factor"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.show(JSON.parse(text).float)
                } catch (e) {
                    root.level = 1
                }
            }
        }
    }
}
