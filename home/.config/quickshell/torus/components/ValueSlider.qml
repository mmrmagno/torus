import QtQuick
import QtQuick.Layouts
import qs

RowLayout {
    id: root

    property real from: 0
    property real to: 1
    property real step: 0.05
    property real value: 0
    property string suffix: ""
    property int decimals: 2
    signal moved(real value)

    readonly property real frac: (value - from) / Math.max(0.0001, to - from)
    spacing: Theme.sp5
    Layout.fillWidth: true

    function setFrom(x) {
        const raw = from + Math.max(0, Math.min(1, x / track.width)) * (to - from)
        moved(Math.round(raw / step) * step)
    }

    Item {
        Layout.fillWidth: true
        Layout.minimumWidth: 140
        implicitHeight: 18

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Theme.track
            radius: Theme.rXs
            color: Theme.surface1
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.frac))
                height: parent.height
                radius: Theme.rXs
                color: Theme.accent
            }
        }

        Rectangle {
            x: Math.max(0, Math.min(track.width - width, track.width * root.frac - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.knob
            height: Theme.knob
            radius: width / 2
            color: Theme.text
            border.width: 2
            border.color: Theme.accent
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => root.setFrom(mouse.x)
            onPositionChanged: mouse => { if (pressed) root.setFrom(mouse.x) }
        }
    }

    Text {
        Layout.preferredWidth: 44
        horizontalAlignment: Text.AlignRight
        text: Number(root.value.toFixed(root.decimals)).toString() + root.suffix
        color: Theme.subtext
        font.family: Theme.fontMono
        font.pixelSize: Theme.fsSm
    }
}
