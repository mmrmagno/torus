import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: win

    readonly property bool fullscreen: screen ? Fullscreen.isFull(screen.name) : false
    readonly property bool shown: Store.wallpaper === "donut"
    property int frames: 0

    visible: shown
    implicitWidth: donut.implicitWidth
    implicitHeight: donut.implicitHeight
    exclusiveZone: -1
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "torus-donut"
    WlrLayershell.layer: WlrLayer.Bottom

    DonutView {
        id: donut
        anchors.fill: parent
        throttle: Fullscreen.any
        live: win.shown && !win.fullscreen && !Store.gamemode && !Store.donutPaused && !Store.locked
        cellH: win.screen ? Math.max(8, Math.round(Math.min(win.screen.width, win.screen.height) * 0.5 / DonutClock.h)) : 16
        onFrame: {
            win.frames++
            Store.reportFrames(win.screen.name, win.frames)
        }
    }
}
