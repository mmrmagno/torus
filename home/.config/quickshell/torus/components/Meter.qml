import QtQuick
import qs

Column {
    property string label: ""
    property string value: ""
    property real fraction: 0
    property color tint: Theme.accent
    spacing: 4
    width: parent ? parent.width : 200

    Row {
        width: parent.width
        Text { text: parent.parent.label; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: 12; width: parent.width / 2 }
        Text { text: parent.parent.value; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: 12; width: parent.width / 2; horizontalAlignment: Text.AlignRight }
    }
    Rectangle {
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surface1
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.parent.fraction))
            height: parent.height
            radius: 3
            color: parent.parent.tint
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }
}
