import QtQuick
import qs

Rectangle {
    id: root

    default property alias content: row.data
    property int pad: 10

    implicitWidth: row.implicitWidth + pad * 2
    implicitHeight: parent ? parent.height : 28
    radius: Theme.radius
    color: Qt.alpha(Theme.base, Theme.glassPill)
    border.width: 1
    border.color: Qt.alpha(Theme.surface1, 0.6)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.sp4
    }
}
