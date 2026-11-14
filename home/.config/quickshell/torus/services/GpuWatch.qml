pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var last: ({})

    Process {
        id: follow
        running: true
        command: ["torus-gpuwatch", "follow"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.last = JSON.parse(line)
                } catch (e) {}
            }
        }
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 30000
        onTriggered: follow.running = true
    }
}
