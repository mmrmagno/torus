import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    id: root
    readonly property bool shown: Island.recording
    icon: "󰑋"
    iconColor: Theme.red
    tip: "Recording, click to stop"
    onClicked: Quickshell.execDetached(["torus-record", "toggle"])

    Timer {
        interval: 1000
        repeat: true
        running: root.shown
        triggeredOnStart: true
        onTriggered: {
            const s = Math.max(0, Math.floor((Date.now() - Island.recordStart) / 1000))
            root.label = String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
        }
    }
}
