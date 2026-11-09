import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
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

    screen: Store.screenFor("overview")
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
        id: stage
        anchors.fill: parent
        color: Qt.alpha(Theme.crust, 0.7)
        focus: true
        property var dragging: null
        property point dragPos: Qt.point(0, 0)
        property size dragSize: Qt.size(0, 0)
        property int hoverWs: -1

        function wsAt(p) {
            const q = stage.mapToItem(grid, p.x, p.y)
            const t = grid.childAt(q.x, q.y)
            return t && t.modelData !== undefined ? t.modelData : -1
        }

        function drop() {
            const w = dragging
            const target = hoverWs
            dragging = null
            hoverWs = -1
            if (!w || target < 0 || (w.workspace && w.workspace.id === target))
                return
            Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + target + ', follow = false, window = "address:0x' + w.address + '" })')
            refresh.restart()
        }

        Timer {
            id: refresh
            interval: 150
            onTriggered: Hyprland.refreshToplevels()
        }
        Keys.onEscapePressed: Store.setOpen("overview", false)
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: event => {
            let n = "1234567890".indexOf(event.text)
            if (n < 0 && event.key >= Qt.Key_1 && event.key <= Qt.Key_9)
                n = event.key - Qt.Key_1
            if (n < 0 && event.key === Qt.Key_0)
                n = 9
            if (n < 0)
                return
            Store.setOpen("overview", false)
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + (n + 1) + '" })')
            event.accepted = true
        }
        TapHandler { onTapped: Store.setOpen("overview", false) }

        Flow {
            id: grid
            anchors.centerIn: parent
            readonly property real tileW: root.width * root.scale
            readonly property int cols: Math.max(1, Math.min(5, Math.floor((parent.width - 80 + spacing) / (tileW + spacing))))
            width: cols * (tileW + spacing) - spacing
            spacing: Theme.sp7

            Repeater {
                id: tiles
                model: root.workspaces

                Rectangle {
                    id: tile
                    required property int modelData
                    readonly property var ws: Hyprland.workspaces.values.find(w => w.id === modelData)
                    readonly property bool active: root.monitor && root.monitor.activeWorkspace && root.monitor.activeWorkspace.id === modelData
                    width: root.width * root.scale
                    height: root.height * root.scale
                    radius: Theme.radius
                    color: Qt.alpha(Theme.base, Theme.glassCard)
                    readonly property bool target: stage.dragging !== null && stage.hoverWs === modelData
                    border.width: active || target ? 2 : 1
                    border.color: target ? Theme.green : (active ? Theme.accent : Theme.surface1)
                    scale: target ? 1.04 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                    clip: true


                    TapHandler {
                        onTapped: {
                            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + tile.modelData + '" })')
                            Store.setOpen("overview", false)
                        }
                    }
                }
            }
        }

        Item {
            id: windowLayer
            anchors.fill: parent

            Repeater {
                model: ScriptModel {
                    values: Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.monitor === root.monitor && root.workspaces.indexOf(t.workspace.id) >= 0)
                }

                Item {
                    id: thumb
                    required property var modelData
                    readonly property int wsId: modelData.workspace ? modelData.workspace.id : -1
                    readonly property Item tileItem: {
                        tiles.count
                        const i = root.workspaces.indexOf(wsId)
                        return i >= 0 ? tiles.itemAt(i) : null
                    }
                    readonly property var ipc: modelData.lastIpcObject || {}
                    readonly property real tw: root.width * root.scale
                    readonly property real th: root.height * root.scale
                    property bool settled: false
                    visible: tileItem !== null
                    opacity: stage.dragging === modelData ? 0.3 : 1
                    width: Math.min(tw, Math.max(12, (ipc.size ? ipc.size[0] : 400) * root.scale))
                    height: Math.min(th, Math.max(12, (ipc.size ? ipc.size[1] : 300) * root.scale))
                    x: tileItem ? grid.x + tileItem.x + Math.max(0, Math.min(tw - width, ((ipc.at ? ipc.at[0] : 0) - (root.monitor ? root.monitor.x : 0)) * root.scale)) : 0
                    y: tileItem ? grid.y + tileItem.y + Math.max(0, Math.min(th - height, ((ipc.at ? ipc.at[1] : 0) - (root.monitor ? root.monitor.y : 0)) * root.scale)) : 0
                    Behavior on x { enabled: thumb.settled; NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: thumb.settled; NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutCubic } }
                    Behavior on width { enabled: thumb.settled; NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutCubic } }
                    Behavior on height { enabled: thumb.settled; NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutCubic } }
                    Component.onCompleted: {
                        cap.captureFrame()
                        Qt.callLater(() => thumb.settled = true)
                    }
                    onWsIdChanged: recapture.restart()

                    Timer {
                        id: recapture
                        property int left: 4
                        interval: 250
                        repeat: true
                        onTriggered: {
                            cap.captureFrame()
                            if (--left <= 0) {
                                stop()
                                left = 4
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: Theme.surface0
                        visible: !cap.hasContent
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: Math.min(parent.width, parent.height) * 0.45
                            source: {
                                DesktopEntries.applications
                                const id = thumb.modelData.wayland && thumb.modelData.wayland.appId ? thumb.modelData.wayland.appId : ""
                                const e = id ? DesktopEntries.heuristicLookup(id) : null
                                return Quickshell.iconPath(e ? e.icon : id.toLowerCase(), "application-x-executable")
                            }
                        }
                    }
                    ScreencopyView {
                        id: cap
                        anchors.fill: parent
                        captureSource: thumb.modelData.wayland
                        live: root.visible && thumb.modelData.workspace !== null && thumb.modelData.workspace.active
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: 4
                        border.width: 1
                        border.color: thumbHover.hovered ? Theme.accent : Qt.alpha(Theme.accent, 0.4)
                    }
                    HoverHandler { id: thumbHover; cursorShape: Qt.OpenHandCursor }
                    TapHandler {
                        onTapped: {
                            Store.setOpen("overview", false)
                            Store.focusWindow(thumb.modelData)
                        }
                    }
                    DragHandler {
                        target: null
                        cursorShape: Qt.ClosedHandCursor
                        onActiveChanged: {
                            if (active) {
                                stage.dragSize = Qt.size(thumb.width, thumb.height)
                                stage.dragging = thumb.modelData
                            } else {
                                stage.drop()
                            }
                        }
                        onCentroidChanged: {
                            if (!active)
                                return
                            stage.dragPos = thumb.mapToItem(stage, centroid.position.x, centroid.position.y)
                            stage.hoverWs = stage.wsAt(stage.dragPos)
                        }
                    }
                }
            }
        }

        Repeater {
            model: root.workspaces
            Rectangle {
                required property int modelData
                required property int index
                readonly property Item t: { tiles.count; return tiles.itemAt(index) }
                readonly property bool active: root.monitor && root.monitor.activeWorkspace && root.monitor.activeWorkspace.id === modelData
                x: t ? grid.x + t.x + 6 : 0
                y: t ? grid.y + t.y + t.height - height - 6 : 0
                width: num.implicitWidth + 12
                height: 20
                radius: 10
                color: active ? Theme.accent : Qt.alpha(Theme.crust, 0.8)
                Text {
                    id: num
                    anchors.centerIn: parent
                    text: parent.modelData
                    color: parent.active ? Theme.crust : Theme.subtext
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsMd
                    font.bold: true
                }
            }
        }

        Item {
            visible: stage.dragging !== null
            x: stage.dragPos.x - width / 2
            y: stage.dragPos.y - height / 2
            width: stage.dragSize.width * 1.1
            height: stage.dragSize.height * 1.1
            z: 10
            ScreencopyView {
                anchors.fill: parent
                captureSource: stage.dragging ? stage.dragging.wayland : null
                live: stage.dragging !== null
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: 6
                border.width: 2
                border.color: stage.hoverWs >= 0 ? Theme.green : Theme.accent
            }
        }
    }
    }
}
