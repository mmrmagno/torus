import QtQuick
import qs

Item {
    id: root

    property string icon: ""
    property string label: ""
    property color iconColor: Theme.accent
    property color labelColor: Theme.text
    property string tip: ""
    property bool available: true
    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(int delta)

    visible: available
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Row {
        id: content
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: root.icon
            visible: root.icon !== ""
            color: hover.hovered ? Theme.lavender : root.iconColor
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSize + 1
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            text: root.label
            visible: root.label !== ""
            color: root.labelColor
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSize
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked()
            else if (mouse.button === Qt.MiddleButton)
                root.middleClicked()
            else
                root.clicked()
        }
        onWheel: wheel => root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1)
    }
}
