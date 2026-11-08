pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property int percent: 0

    function refresh() {
        proc.running = true
    }

    function adjust(delta) {
        Quickshell.execDetached(["brightnessctl", "-q", "set", Math.abs(delta) + "%" + (delta > 0 ? "+" : "-")])
        refreshTimer.restart()
    }

    Process {
        id: proc
        command: ["sh", "-c", "ls /sys/class/backlight/ 2>/dev/null | grep -q . && brightnessctl -m | cut -d, -f4 | tr -d %"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text)
                root.available = !isNaN(v)
                root.percent = isNaN(v) ? 0 : v
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 200
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
