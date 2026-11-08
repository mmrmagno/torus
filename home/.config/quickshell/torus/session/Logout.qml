import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

PanelWindow {
    id: root

    readonly property var actions: [
        { icon: "󰌾", label: "Lock", key: "l", cmd: ["torus-lock"] },
        { icon: "󰍃", label: "Logout", key: "e", cmd: ["uwsm", "stop"] },
        { icon: "󰤄", label: "Suspend", key: "u", cmd: ["systemctl", "suspend"] },
        { icon: "󰒲", label: "Hibernate", key: "h", cmd: ["systemctl", "hibernate"] },
        { icon: "󰜉", label: "Reboot", key: "r", cmd: ["systemctl", "reboot"] },
        { icon: "󰐥", label: "Shutdown", key: "s", cmd: ["systemctl", "poweroff"] }
    ]

    function run(a) {
        Store.setOpen("logout", false)
        Quickshell.execDetached(a.cmd)
    }

    screen: Store.focusedScreen
    visible: Store.isOpen("logout")
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.namespace: "torus-logout"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.crust, 0.6)
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Store.setOpen("logout", false)
                return
            }
            for (const a of root.actions)
                if (event.text === a.key)
                    root.run(a)
        }
        TapHandler { onTapped: Store.setOpen("logout", false) }

        Row {
            anchors.centerIn: parent
            spacing: 18

            Repeater {
                model: root.actions

                Rectangle {
                    required property var modelData
                    width: 128
                    height: 140
                    radius: 18
                    color: hover.hovered ? Qt.alpha(Theme.accent, 0.25) : Qt.alpha(Theme.base, 0.9)
                    border.width: hover.hovered ? 2 : 1
                    border.color: hover.hovered ? Theme.accent : Theme.surface1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.modelData.icon
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: 40
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.modelData.label
                            color: Theme.text
                            font.family: Theme.fontUi
                            font.pixelSize: 14
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.modelData.key
                            color: Theme.overlay
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                        }
                    }

                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.run(parent.modelData) }
                }
            }
        }
    }
}
