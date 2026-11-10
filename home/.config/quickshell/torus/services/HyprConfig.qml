pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property string errors: ""

    function check() {
        if (!probe.running)
            probe.running = true
    }

    Component.onCompleted: check()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                settle.restart()
        }
    }

    Timer {
        id: settle
        interval: 600
        onTriggered: root.check()
    }

    Process {
        id: probe
        command: ["hyprctl", "configerrors"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").filter(l => l.trim() !== "").join("\n")
                if (found !== "" && found !== root.errors)
                    Quickshell.execDetached(["notify-send", "-a", "torus", "-u", "critical", "Hyprland config error", found.split("\n")[0] + "\ntorus doctor shows the rest"])
                root.errors = found
            }
        }
    }
}
