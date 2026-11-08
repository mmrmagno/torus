import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

PanelWindow {
    id: root

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property real scale: 0.18
    readonly property var workspaces: {
        const ids = Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === monitor).map(w => w.id)
        for (let i = 1; i <= 10; i++)
            if (ids.indexOf(i) < 0 && ids.length < 10)
                ids.push(i)
        return ids.sort((a, b) => a - b)
    }

    screen: Store.focusedScreen
    visible: Store.isOpen("overview")
    onVisibleChanged: if (visible) Hyprland.refreshToplevels()
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Loader {
        anchors.fill: parent
        active: root.visible
        sourceComponent: content
    }

    Component {
        id: content
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.crust, 0.7)
        focus: true
        Keys.onEscapePressed: Store.setOpen("overview", false)
        Keys.onPressed: event => {
            const n = "1234567890".indexOf(event.text)
            if (n < 0)
                return
            Store.setOpen("overview", false)
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + (n + 1) + '" })')
            event.accepted = true
        }
        TapHandler { onTapped: Store.setOpen("overview", false) }

        Flow {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 5 * (root.width * root.scale + 16))
            spacing: 16

            Repeater {
                model: root.workspaces

                Rectangle {
                    id: tile
                    required property int modelData
                    readonly property var ws: Hyprland.workspaces.values.find(w => w.id === modelData)
                    readonly property bool active: root.monitor && root.monitor.activeWorkspace && root.monitor.activeWorkspace.id === modelData
                    width: root.width * root.scale
                    height: root.height * root.scale
                    radius: 10
                    color: Qt.alpha(Theme.base, Theme.glassCard)
                    border.width: active ? 2 : 1
                    border.color: active ? Theme.accent : Theme.surface1
                    clip: true

                    Repeater {
                        model: tile.ws ? tile.ws.toplevels.values : []
                        Item {
                            required property var modelData
                            readonly property var ipc: modelData.lastIpcObject || {}
                            x: ((ipc.at ? ipc.at[0] : 0) - (root.monitor ? root.monitor.x : 0)) * root.scale
                            y: ((ipc.at ? ipc.at[1] : 0) - (root.monitor ? root.monitor.y : 0)) * root.scale
                            width: (ipc.size ? ipc.size[0] : 100) * root.scale
                            height: (ipc.size ? ipc.size[1] : 100) * root.scale
                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: parent.modelData.wayland
                                live: root.visible
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: 4
                                border.width: 1
                                border.color: Qt.alpha(Theme.accent, 0.4)
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        text: tile.modelData
                        color: tile.active ? Theme.accent : Theme.subtext
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                        font.bold: true
                    }

                    TapHandler {
                        onTapped: {
                            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + tile.modelData + '" })')
                            Store.setOpen("overview", false)
                        }
                    }
                }
            }
        }
    }
    }
}
