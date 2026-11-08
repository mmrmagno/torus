pragma Singleton
import QtQuick
import Quickshell
import qs

Singleton {
    id: root

    property bool running: false
    property real endsAt: 0
    property int total: 0
    property int left: 0
    property bool dndBefore: false
    readonly property real progress: total > 0 ? 1 - left / total : 0

    function start(minutes) {
        if (!running)
            dndBefore = Store.dnd
        total = Math.max(1, Math.round(minutes * 60))
        endsAt = Date.now() + total * 1000
        left = total
        running = true
        Store.dnd = true
    }

    function stop() {
        if (!running)
            return
        running = false
        left = 0
        Store.dnd = dndBefore
    }

    function finish() {
        stop()
        Quickshell.execDetached(["sh", "-c", "pw-play /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || true"])
        Quickshell.execDetached(["notify-send", "-a", "torus", "Focus done", "Take a break"])
    }

    Timer {
        interval: 250
        repeat: true
        running: root.running
        onTriggered: {
            root.left = Math.max(0, Math.ceil((root.endsAt - Date.now()) / 1000))
            if (root.left === 0)
                root.finish()
        }
    }
}
