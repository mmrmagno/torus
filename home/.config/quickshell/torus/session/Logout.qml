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

    property int selected: 0
    onVisibleChanged: if (visible) selected = 0

    function run(a) {
        Store.setOpen("logout", false)
        if (a.key === "e" || a.key === "r" || a.key === "s")
            Quickshell.execDetached(["sh", "-c", "torus-session save; exec \"$@\"", "torus-session"].concat(a.cmd))
        else
            Quickshell.execDetached(a.cmd)
    }

    screen: Store.screenFor("logout")
    visible: Store.isOpen("logout") || motion.leaving
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
    WlrLayershell.keyboardFocus: Store.isOpen("logout") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        PanelMotion {
            id: motion
            target: parent
            shown: Store.isOpen("logout")
        }
        anchors.fill: parent
        color: Qt.alpha(Theme.crust, 0.6)
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Store.setOpen("logout", false)
                return
            }
            const n = root.actions.length
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                root.selected = (root.selected + 1) % n
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                root.selected = (root.selected - 1 + n) % n
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.run(root.actions[root.selected])
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
                    required property int index
                    readonly property bool lit: root.selected === index
                    width: 128
                    height: 140
                    radius: Theme.rPanel
                    color: lit ? Qt.alpha(Theme.accent, 0.25) : Qt.alpha(Theme.base, Theme.glassCard)
                    border.width: lit ? 2 : 1
                    border.color: lit ? Theme.accent : Theme.surface1
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.sp5
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
                            font.pixelSize: Theme.fsLg
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.modelData.key
                            color: Theme.overlay
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsSm
                        }
                    }

                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.selected = parent.index }
                    TapHandler { onTapped: root.run(parent.modelData) }
                }
            }
        }
    }
}
