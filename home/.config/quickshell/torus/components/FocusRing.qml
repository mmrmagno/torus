import QtQuick
import qs

Rectangle {
    property bool on: false
    property real pad: 3
    property real baseRadius: Theme.radius
    anchors.fill: parent
    anchors.margins: -pad
    z: 100
    radius: baseRadius + pad
    color: "transparent"
    border.width: 2
    border.color: Theme.accent
    opacity: on ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
}
