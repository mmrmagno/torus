import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

PanelWindow {
    id: win

    readonly property bool fullscreen: screen ? Fullscreen.isFull(screen.name) : false
    readonly property bool shown: Store.wallFor(win.screen ? win.screen.name : "") === "donut" || Store.wallFor(win.screen ? win.screen.name : "") === "xwing"
    property int frames: 0
    property real drift: 0
    property int lastWs: 0
    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property int ws: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 0

    onWsChanged: {
        if (lastWs > 0 && ws > 0 && ws !== lastWs && !Store.gamemode) {
            nudge.stop()
            out.to = ws > lastWs ? -36 : 36
            nudge.start()
        }
        lastWs = ws
    }

    SequentialAnimation {
        id: nudge
        NumberAnimation { id: out; target: win; property: "drift"; duration: Theme.durFast; easing.type: Easing.OutCubic }
        NumberAnimation { target: win; property: "drift"; to: 0; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }

    visible: shown
    implicitWidth: donut.implicitWidth + 96
    implicitHeight: donut.implicitHeight
    exclusiveZone: -1
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "torus-donut"
    WlrLayershell.layer: WlrLayer.Bottom

    DonutView {
        id: donut
        width: implicitWidth
        height: parent.height
        x: (parent.width - width) / 2 + win.drift
        throttle: Fullscreen.any
        shape: Store.wallFor(win.screen ? win.screen.name : "") === "xwing" ? "xwing" : "torus"
        live: win.shown && !win.fullscreen && !Store.gamemode && !Store.donutPaused && !Store.locked
        cellH: win.screen ? Math.max(8, Math.round(Math.min(win.screen.width, win.screen.height) * 0.5 / (Store.wallFor(win.screen ? win.screen.name : "") === "xwing" ? DonutClock.h * 2 : DonutClock.h))) : 16
        onFrame: {
            win.frames++
            Store.reportFrames(win.screen.name, win.frames)
        }
    }
}
