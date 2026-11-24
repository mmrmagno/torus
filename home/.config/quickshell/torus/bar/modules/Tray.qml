import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.components
import qs.services

import Quickshell.Services.SystemTray
import Quickshell.Widgets

Row {
    id: root
    property bool available: true
    function hits() {
        return children.filter(c => c.area).map(c => [c.area.width, c.area.height])
    }
    spacing: 0

    Repeater {
        model: SystemTray.items.values

        Item {
            id: icon
            required property var modelData
            readonly property Item area: trayArea
            property bool menuOpen: false
            property bool menuKeep: false
            onMenuOpenChanged: if (!menuOpen && Theme.motion > 0) {
                menuKeep = true
                menuTimer.restart()
            }
            Timer {
                id: menuTimer
                interval: Theme.durFast + 60
                onTriggered: icon.menuKeep = false
            }
            implicitWidth: 28
            implicitHeight: 14
            anchors.verticalCenter: parent.verticalCenter

            IconImage {
                anchors.centerIn: parent
                implicitSize: 14
                source: icon.modelData.icon
                layer.enabled: !Theme.dark
                layer.effect: MultiEffect { brightness: -0.55 }
                scale: trayArea.pressed ? 0.85 : hover.hovered ? 1.15 : 1
                Behavior on scale { NumberAnimation { duration: Theme.durFast } }
            }

            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

            MouseArea {
                id: trayArea
                anchors.centerIn: parent
                width: icon.width
                height: Store.barHeight
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
                active: icon.menuOpen || icon.menuKeep
                TrayMenu {
                    anchorItem: icon
                    shown: icon.menuOpen
                    root_menu: icon.modelData.menu
                    onDismissed: icon.menuOpen = false
                }
            }
        }
    }
}
