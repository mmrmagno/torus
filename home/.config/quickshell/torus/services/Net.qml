pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property alias type: kept.type
    property alias name: kept.name

    PersistentProperties {
        id: kept
        reloadableId: "torus-net"
        property string type: "none"
        property string name: ""
    }
    readonly property bool online: type !== "none"
    property bool known: false
    onOnlineChanged: if (known) Store.sound(online ? "online" : "offline")

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
                root.known = true
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
