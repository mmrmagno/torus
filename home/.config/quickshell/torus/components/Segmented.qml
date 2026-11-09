import QtQuick
import qs

Rectangle {
    id: root

    property var options: []
    property var labels: []
    property string current: ""
    signal picked(string value)

    implicitWidth: row.implicitWidth + 6
    implicitHeight: 30
    radius: height / 2
    color: Theme.surface0

    Rectangle {
        id: thumb
        readonly property Item target: row.children.length > 0 ? row.children[Math.max(0, root.options.indexOf(root.current))] : null
        visible: target !== null && root.options.indexOf(root.current) >= 0
        x: target ? row.x + target.x : 0
        y: 3
        width: target ? target.width : 0
        height: root.height - 6
        radius: height / 2
        color: Theme.accent
        Behavior on x { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: 3

        Repeater {
            model: root.options
            Item {
                required property string modelData
                required property int index
                readonly property bool on: modelData === root.current
                width: label.implicitWidth + 24
                height: root.height - 6
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: root.labels[parent.index] || parent.modelData
                    color: parent.on ? Theme.crust : (hover.hovered ? Theme.text : Theme.subtext)
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                    font.weight: parent.on ? Font.DemiBold : Font.Normal
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.picked(parent.modelData) }
            }
        }
    }
}
