import QtQuick
import qs

Column {
    property string label: ""
    property string value: ""
    property real fraction: 0
    property color tint: Theme.accent
    spacing: Theme.sp2
    width: parent ? parent.width : 200

    Row {
        width: parent.width
        Text { text: parent.parent.label; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd; width: parent.width / 2 }
        Text { text: parent.parent.value; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd; width: parent.width / 2; horizontalAlignment: Text.AlignRight }
    }
    Rectangle {
        width: parent.width
        height: 6
        radius: Theme.rXs
        color: Theme.surface1
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.parent.fraction))
            height: parent.height
            radius: Theme.rXs
            color: parent.parent.tint
            Behavior on width { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutCubic } }
        }
    }
}
