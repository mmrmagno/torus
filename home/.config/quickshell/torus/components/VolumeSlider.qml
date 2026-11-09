import QtQuick
import qs

Item {
    id: root

    property var audio: null
    readonly property real value: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false

    implicitHeight: 18

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: Theme.rXs
        color: Theme.surface1

        Rectangle {
            width: parent.width * Math.min(1, root.value)
            height: parent.height
            radius: Theme.rXs
            color: root.muted ? Theme.overlay : (root.value > 1 ? Theme.peach : Theme.accent)
            Behavior on width { NumberAnimation { duration: 90 } }
        }
    }

    Rectangle {
        x: Math.max(0, Math.min(track.width - width, track.width * Math.min(1, root.value) - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: 7
        color: Theme.text
        border.width: 2
        border.color: root.muted ? Theme.overlay : Theme.accent
        scale: drag.pressed || drag.containsMouse ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: Theme.durFast } }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function set(x) {
            if (root.audio)
                root.audio.volume = Math.max(0, Math.min(1, x / track.width))
        }
        onPressed: mouse => set(mouse.x)
        onPositionChanged: mouse => { if (pressed) set(mouse.x) }
        onWheel: wheel => {
            if (root.audio)
                root.audio.volume = Math.max(0, Math.min(1.5, root.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
        }
    }
}
