import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

import Quickshell.Services.SystemTray
import Quickshell.Widgets

Row {
    id: root
    property bool available: true
    spacing: 8

    Repeater {
        model: SystemTray.items.values

        IconImage {
            id: icon
            required property var modelData
            implicitSize: 14
            anchors.verticalCenter: parent.verticalCenter
            source: modelData.icon

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    const item = icon.modelData
                    if (mouse.button === Qt.RightButton || item.onlyMenu) {
                        const p = icon.mapToItem(null, 0, icon.height + 6)
                        item.display(root.QsWindow.window, p.x, p.y)
                    } else if (mouse.button === Qt.MiddleButton) {
                        item.secondaryActivate()
                    } else {
                        item.activate()
                    }
                }
            }
        }
    }
}
