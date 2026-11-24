import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services

PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Fly.screenName) || Quickshell.screens[0]
    visible: Fly.on
    anchors {
        top: true
        left: true
    }
    readonly property real left: edge("x", "w", Math.min, 0)
    readonly property real top: edge("y", "h", Math.min, 0)
    margins.left: left
    margins.top: top
    implicitWidth: Math.max(1, edge("x", "w", Math.max, 1) - left)
    implicitHeight: Math.max(1, edge("y", "h", Math.max, 1) - top)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "torus-fly"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    onBackingWindowVisibleChanged: if (backingWindowVisible) Fly.shown()

    function edge(at, size, pick, far) {
        return Fly.start && Fly.end ? pick(Fly.start[at] + far * Fly.start[size], Fly.end[at] + far * Fly.end[size]) : 0
    }

    function mix(k) {
        return Fly.start && Fly.end ? Fly.start[k] + (Fly.end[k] - Fly.start[k]) * Fly.p : 0
    }

    ClippingRectangle {
        visible: Fly.on
        x: root.mix("x") - root.left
        y: root.mix("y") - root.top
        width: root.mix("w")
        height: root.mix("h")
        radius: root.mix("r")
        color: Theme.surface0
        Image {
            anchors.fill: parent
            source: Fly.art
            sourceSize.width: 160
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
}
