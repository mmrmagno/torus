import QtQuick
import qs

Item {
    id: fade

    required property Flickable flick
    property color tint: Theme.base
    readonly property bool above: flick.contentY > 1
    readonly property bool below: flick.contentY + flick.height < flick.contentHeight - 1

    anchors.fill: flick
    z: 50

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 22
        opacity: fade.above ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(fade.tint, 0.92) }
            GradientStop { position: 1; color: Qt.alpha(fade.tint, 0) }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 22
        opacity: fade.below ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(fade.tint, 0) }
            GradientStop { position: 1; color: Qt.alpha(fade.tint, 0.92) }
        }
    }
}
