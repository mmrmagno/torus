import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets

ShellRoot {
    id: root

    readonly property color base: "#1e1e2e"
    readonly property color surface: "#313244"
    readonly property color text: "#cdd6f4"
    readonly property color dim: "#7f849c"
    readonly property color red: "#f38ba8"
    readonly property color accent: "#cba6f7"
    readonly property string font: "Cantarell"

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData
            anchors.top: true
            anchors.left: true
            anchors.right: true
            implicitHeight: 30
            color: root.base

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Repeater {
                    model: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor && w.monitor.name === bar.modelData.name)
                    Rectangle {
                        required property var modelData
                        implicitWidth: 24
                        implicitHeight: 20
                        radius: 6
                        color: modelData.focused ? root.accent : root.surface
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.id
                            color: parent.modelData.focused ? root.base : root.text
                            font.family: root.font
                            font.pixelSize: 12
                        }
                        TapHandler { onTapped: Hyprland.dispatch('hl.dsp.focus({ workspace = "' + parent.modelData.id + '" })') }
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: warn.implicitWidth + 16
                    implicitHeight: 22
                    radius: 11
                    color: Qt.alpha(root.red, 0.2)
                    Text {
                        id: warn
                        anchors.centerIn: parent
                        text: "safe mode: the torus shell stopped"
                        color: root.red
                        font.family: root.font
                        font.pixelSize: 12
                    }
                }
                Button { label: "Restart shell"; onClicked: Quickshell.execDetached(["torus", "unsafe"]) }
                Button { label: "Log"; onClicked: Quickshell.execDetached(["kitty", "-e", "journalctl", "--user", "-u", "torus-shell", "-e"]) }
                Button { label: "Doctor"; onClicked: Quickshell.execDetached(["kitty", "--hold", "-e", "torus", "doctor"]) }

                Item { Layout.fillWidth: true }

                Repeater {
                    model: SystemTray.items
                    IconImage {
                        id: trayIcon
                        required property var modelData
                        implicitSize: 16
                        source: modelData.icon
                        TapHandler {
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onTapped: (point, button) => {
                                if (button === Qt.RightButton || trayIcon.modelData.onlyMenu)
                                    trayIcon.modelData.display(bar, bar.width - 200, bar.height)
                                else
                                    trayIcon.modelData.activate()
                            }
                        }
                    }
                }

                Text {
                    text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
                    color: root.text
                    font.family: root.font
                    font.pixelSize: 13
                }
            }
        }
    }

    component Button: Rectangle {
        id: btn
        property string label: ""
        signal clicked
        implicitWidth: btnText.implicitWidth + 16
        implicitHeight: 22
        radius: 11
        color: btnHover.hovered ? root.accent : root.surface
        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.label
            color: btnHover.hovered ? root.base : root.text
            font.family: root.font
            font.pixelSize: 12
        }
        HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: btn.clicked() }
    }
}
