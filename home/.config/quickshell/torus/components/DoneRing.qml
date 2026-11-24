import QtQuick
import qs

Item {
    id: root

    property bool on: false
    property var of: null
    onOfChanged: if (on) start()
    property real p: 1
    property real tick: 1

    implicitWidth: 28
    implicitHeight: 28
    onOnChanged: if (on) start()
    Component.onCompleted: if (on) start()

    function start() {
        Store.doneRings++
        if (Theme.motion === 0)
            return
        run.restart()
    }

    SequentialAnimation {
        id: run
        PropertyAction { target: root; property: "tick"; value: 0 }
        NumberAnimation { target: root; property: "p"; from: 0.75; to: 1; duration: Theme.durSlow; easing.type: Easing.InOutCubic }
        NumberAnimation { target: root; property: "tick"; from: 0; to: 1; duration: Theme.durSlow; easing.type: Easing.OutCubic }
    }

    ProgressRing {
        anchors.fill: parent
        thickness: 2.5
        value: root.p
        tint: Theme.green
    }

    Canvas {
        id: mark
        anchors.centerIn: parent
        width: 22
        height: 22
        property real p: root.tick
        onPChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.lineWidth = 2.2
            c.lineCap = "round"
            c.lineJoin = "round"
            c.strokeStyle = Theme.green
            const pts = [[6.5, 11.5], [9.8, 14.8], [15.5, 8]]
            const a = Math.hypot(3.3, 3.3), b = Math.hypot(5.7, 6.8)
            let left = mark.p * (a + b)
            if (left <= 0)
                return
            c.beginPath()
            c.moveTo(pts[0][0], pts[0][1])
            const t = Math.min(1, left / a)
            c.lineTo(pts[0][0] + 3.3 * t, pts[0][1] + 3.3 * t)
            left -= a
            if (left > 0) {
                const u = Math.min(1, left / b)
                c.lineTo(pts[1][0] + 5.7 * u, pts[1][1] - 6.8 * u)
            }
            c.stroke()
        }
    }
}
