import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

import Quickshell.Hyprland

Row {
    id: root
    property bool available: true
    property var monitor: QsWindow.window ? Hyprland.monitorFor(QsWindow.window.screen) : null
    spacing: 6

    Repeater {
        model: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor)

        Rectangle {
            required property var modelData
            readonly property bool active: modelData.active
            width: active ? 22 : 16
            height: 12
            radius: 6
            anchors.verticalCenter: parent.verticalCenter
            color: active ? Theme.accent : (modelData.urgent ? Theme.red : Theme.surface1)
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 180 } }

            Text {
                anchors.centerIn: parent
                text: parent.modelData.id
                color: parent.active ? Theme.crust : Theme.subtext
                font.family: Theme.fontMono
                font.pixelSize: 8
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.modelData.activate()
            }
        }
    }
}
