import QtQuick
import qs

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool active: false
    signal clicked

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 34
    radius: 10
    color: active ? Theme.accent : (hover.hovered ? Theme.surface1 : Theme.surface0)
    Behavior on color { ColorAnimation { duration: 150 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            text: root.icon
            visible: root.icon !== ""
            color: root.active ? Theme.crust : Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: 15
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.label
            visible: root.label !== ""
            color: root.active ? Theme.crust : Theme.text
            font.family: Theme.fontUi
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.clicked() }
}
