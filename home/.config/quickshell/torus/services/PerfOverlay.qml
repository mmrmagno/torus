pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property bool on: false
    property bool installed: false

    function toggle() {
        if (!toggler.running)
            toggler.running = true
    }

    Process {
        id: toggler
        command: ["torus-mangohud", "toggle"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.on = text.trim() === "on"
                Island.flash("osd", { icon: "󰄨", label: root.on ? "Overlay on" : "Overlay off", value: -1 }, 1600)
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v mangohud > /dev/null && echo yes; torus-mangohud status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.installed = text.includes("yes")
                root.on = text.trim().endsWith("on")
            }
        }
    }
}
