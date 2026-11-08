pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string type: "none"
    property string name: ""
    readonly property bool online: type !== "none"

    Process {
        id: proc
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let found = null
                for (const line of text.split("\n")) {
                    const [t, s, c] = line.split(":")
                    if (s === "connected" && (t === "ethernet" || t === "wifi")) {
                        found = { t, c }
                        break
                    }
                }
                root.type = found ? found.t : "none"
                root.name = found ? found.c : ""
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
}
