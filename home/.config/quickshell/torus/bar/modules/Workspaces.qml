import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

Row {
    id: root
    property bool available: true
    property var monitor: QsWindow.window ? Hyprland.monitorFor(QsWindow.window.screen) : null
    readonly property int h: Math.max(16, Store.barHeight - 8)
    spacing: Theme.sp2

    function appsOn(ws) {
        DesktopEntries.applications
        const seen = {}
        const out = []
        for (const t of Hyprland.toplevels.values) {
            if (t.workspace !== ws)
                continue
            const id = t.wayland && t.wayland.appId ? t.wayland.appId : (t.lastIpcObject ? t.lastIpcObject.class || "" : "")
            if (!id || seen[id])
                continue
            seen[id] = true
            const e = DesktopEntries.heuristicLookup(id)
            out.push(Quickshell.iconPath(e ? e.icon : id.toLowerCase(), "application-x-executable"))
        }
        return out
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const ids = Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor).map(w => w.id).sort((a, b) => a - b)
            const cur = root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : ids[0]
            const i = ids.indexOf(cur) + (event.angleDelta.y > 0 ? -1 : 1)
            if (i >= 0 && i < ids.length)
                Hyprland.dispatch('hl.dsp.focus({ workspace = "' + ids[i] + '" })')
        }
    }

    Repeater {
        model: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor)

        Rectangle {
            id: ws
            required property var modelData
            readonly property bool active: modelData.active
            readonly property var icons: active ? [] : root.appsOn(modelData).slice(0, 3)
            implicitWidth: Math.max(root.h + 4, row.implicitWidth + 12)
            width: implicitWidth
            height: root.h
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: active ? Theme.accent : (modelData.urgent ? Qt.alpha(Theme.red, 0.25) : (hover.hovered ? Theme.surface1 : Qt.alpha(Theme.surface0, 0.9)))
            border.width: modelData.urgent && !active ? 1 : 0
            border.color: Theme.red
            Behavior on width { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.durMed } }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: Theme.sp2
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ws.modelData.name && isNaN(Number(ws.modelData.name)) ? ws.modelData.name : ws.modelData.id
                    color: ws.active ? Theme.crust : Theme.subtext
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsXs
                    font.bold: true
                }
                Repeater {
                    model: ws.icons
                    IconImage {
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: root.h - 6
                        source: modelData
                        opacity: hover.hovered ? 1 : 0.8
                    }
                }
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered && !ws.active && ws.icons.length > 0)
                        peekTimer.restart()
                    else {
                        peekTimer.stop()
                        ws.peek = false
                    }
                }
            }
            property bool peek: false
            Timer {
                id: peekTimer
                interval: 450
                onTriggered: ws.peek = hover.hovered
            }

            LazyLoader {
                active: ws.peek
                PopupWindow {
                    id: peekWin
                    anchor.item: ws
                    anchor.rect: Qt.rect(0, 0, ws.width, ws.height + 10)
                    anchor.edges: Edges.Bottom
                    anchor.gravity: Edges.Bottom
                    readonly property real k: 260 / (root.monitor ? root.monitor.width : 2560)
                    implicitWidth: Math.max(16, shotFrame.width || 0)
                    implicitHeight: Math.max(16, shotFrame.height || 0)
                    color: "transparent"
                    visible: true

                    Rectangle {
                        id: shotFrame
                        width: (root.monitor ? root.monitor.width : 2560) * peekWin.k + 16
                        height: (root.monitor ? root.monitor.height : 1440) * peekWin.k + 16
                        radius: Theme.radius + 2
                        color: Qt.alpha(Theme.mantle, 0.95)
                        border.width: 1
                        border.color: Qt.alpha(Theme.accent, 0.35)
                        opacity: 0
                        scale: 0.96
                        transformOrigin: Item.Top
                        Component.onCompleted: {
                            opacity = 1
                            scale = 1
                        }
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                        Behavior on scale { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }

                        Item {
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true
                            Repeater {
                                model: ws.modelData.toplevels.values
                                Item {
                                    required property var modelData
                                    readonly property var ipc: modelData.lastIpcObject || {}
                                    readonly property real k: peekWin.k
                                    x: ((ipc.at ? ipc.at[0] : 0) - (root.monitor ? root.monitor.x : 0)) * k
                                    y: ((ipc.at ? ipc.at[1] : 0) - (root.monitor ? root.monitor.y : 0)) * k
                                    width: (ipc.size ? ipc.size[0] : 100) * k
                                    height: (ipc.size ? ipc.size[1] : 100) * k
                                    ScreencopyView {
                                        anchors.fill: parent
                                        captureSource: parent.modelData.wayland
                                        live: true
                                    }
                                    Rectangle { anchors.fill: parent; color: "transparent"; radius: 3; border.width: 1; border.color: Qt.alpha(Theme.accent, 0.3) }
                                }
                            }
                        }
                    }
                }
            }
            TapHandler { onTapped: Hyprland.dispatch('hl.dsp.focus({ workspace = "' + ws.modelData.id + '" })') }
        }
    }
}
