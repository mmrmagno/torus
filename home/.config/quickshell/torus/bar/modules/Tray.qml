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
            property bool menuOpen: false
            implicitSize: 14
            anchors.verticalCenter: parent.verticalCenter
            source: modelData.icon
            scale: hover.hovered ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }

            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    const item = icon.modelData
                    if (mouse.button === Qt.MiddleButton)
                        item.secondaryActivate()
                    else if (item.hasMenu && (mouse.button === Qt.RightButton || item.onlyMenu || /nm-applet|udiskie|blueman/i.test(item.id + " " + item.title)))
                        icon.menuOpen = !icon.menuOpen
                    else
                        item.activate()
                }
            }

            LazyLoader {
                active: icon.menuOpen
                TrayMenu {
                    anchorItem: icon
                    root_menu: icon.modelData.menu
                    onDismissed: icon.menuOpen = false
                }
            }
        }
    }
}
