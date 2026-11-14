import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: ring

    property real value: 0
    property color tint: Theme.accent
    property real thickness: 2.5
    readonly property bool busy: value < 0
    property real drawn: busy ? 0.28 : Math.max(0, Math.min(1, value))
    property real spin: 0

    implicitWidth: 18
    implicitHeight: 18

    NumberAnimation on spin {
        running: ring.busy && ring.visible
        from: 0
        to: 360
        duration: 1100
        loops: Animation.Infinite
    }

    Behavior on drawn { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.alpha(ring.tint, 0.25)
            strokeWidth: ring.thickness
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.thickness
                radiusY: ring.height / 2 - ring.thickness
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: ring.tint
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.thickness
                radiusY: ring.height / 2 - ring.thickness
                startAngle: -90 + (ring.busy ? ring.spin : 0)
                sweepAngle: 360 * ring.drawn
            }
        }
    }
}
