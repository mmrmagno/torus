import QtQuick
import qs

Item {
    id: ring

    property string phase: "idle"
    property real sweep: 0
    property real check: 0
    readonly property color tint: phase === "fail" ? Theme.red : (phase === "ok" ? Theme.green : Theme.accent)

    implicitWidth: 22
    implicitHeight: 22

    NumberAnimation on sweep {
        running: ring.phase === "scan" && ring.visible
        from: 0
        to: 12
        duration: 1100
        loops: Animation.Infinite
    }

    onPhaseChanged: {
        if (phase === "ok") {
            check = 0
            checkAnim.restart()
        } else if (phase === "fail") {
            shake.restart()
        }
    }

    NumberAnimation { id: checkAnim; target: ring; property: "check"; from: 0; to: 1; duration: Theme.durSlow; easing.type: Easing.OutCubic }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: dots; property: "x"; to: -4; duration: 50 }
        NumberAnimation { target: dots; property: "x"; to: 4; duration: 70 }
        NumberAnimation { target: dots; property: "x"; to: -3; duration: 60 }
        NumberAnimation { target: dots; property: "x"; to: 2; duration: 50 }
        NumberAnimation { target: dots; property: "x"; to: 0; duration: 40 }
    }

    Item {
        id: dots
        width: ring.width
        height: ring.height
        opacity: ring.phase === "ok" ? 1 - ring.check * 0.75 : 1

        Repeater {
            model: 12
            Rectangle {
                id: dot
                required property int index
                readonly property real a: index / 12 * 2 * Math.PI - Math.PI / 2
                readonly property real lag: ((ring.sweep - index) % 12 + 12) % 12
                width: 3
                height: 3
                radius: 1.5
                x: dots.width / 2 + Math.cos(a) * (dots.width / 2 - 2) - 1.5
                y: dots.height / 2 + Math.sin(a) * (dots.height / 2 - 2) - 1.5
                color: ring.tint
                opacity: ring.phase === "scan" ? Math.max(0.2, 1 - dot.lag / 6) : 1
            }
        }
    }

    Canvas {
        id: mark
        anchors.fill: parent
        visible: ring.phase === "ok"
        property real p: ring.check
        onPChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.lineWidth = 2.2
            c.lineCap = "round"
            c.lineJoin = "round"
            c.strokeStyle = Theme.green
            const pts = [[6, 11.5], [9.5, 15], [16, 7.5]]
            const l1 = Math.hypot(3.5, 3.5), l2 = Math.hypot(6.5, 7.5)
            let left = mark.p * (l1 + l2)
            c.beginPath()
            c.moveTo(pts[0][0], pts[0][1])
            const t1 = Math.min(1, left / l1)
            c.lineTo(pts[0][0] + 3.5 * t1, pts[0][1] + 3.5 * t1)
            left -= l1
            if (left > 0) {
                const t2 = Math.min(1, left / l2)
                c.lineTo(pts[1][0] + 6.5 * t2, pts[1][1] - 7.5 * t2)
            }
            c.stroke()
        }
    }
}
