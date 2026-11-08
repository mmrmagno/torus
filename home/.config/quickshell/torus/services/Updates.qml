pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int count: -1

    function check() {
        proc.running = true
    }

    Process {
        id: proc
        command: ["sh", "-c", "{ checkupdates 2>/dev/null; yay -Qua 2>/dev/null; } | grep -c ."]
        stdout: StdioCollector {
            onStreamFinished: root.count = parseInt(text) || 0
        }
    }

    Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.check()
    }
}
