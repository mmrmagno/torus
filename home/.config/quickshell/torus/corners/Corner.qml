import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: root

    property bool atTop: true
    property bool atLeft: true
    readonly property int r: 12

    property string screenName: ""
    readonly property bool covered: Fullscreen.isFull(screenName)

    visible: !covered
    anchors.top: atTop
    anchors.bottom: !atTop
    anchors.left: atLeft
    anchors.right: !atLeft
    implicitWidth: r
    implicitHeight: r
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "torus-corner"
    WlrLayershell.layer: WlrLayer.Overlay

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        rotation: root.atTop ? (root.atLeft ? 0 : 90) : (root.atLeft ? 270 : 180)
        ShapePath {
            fillColor: "black"
            strokeWidth: -1
            startX: 0
            startY: 0
            PathLine { x: root.r; y: 0 }
            PathArc { x: 0; y: root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
            PathLine { x: 0; y: 0 }
        }
    }
}
