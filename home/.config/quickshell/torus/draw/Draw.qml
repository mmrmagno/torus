import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    property var strokes: []
    property var live: null
    property int pen: 0
    readonly property var pens: [Theme.accent, Theme.red, Theme.yellow, Theme.green]
    readonly property real thick: 4

    function close() {
        Store.setOpen("draw", false)
    }

    function commit(s) {
        if (!s || (s.kind === "line" && s.pts.length < 2))
            return
        strokes = strokes.concat([s])
        done.requestPaint()
    }

    function undo() {
        if (strokes.length === 0)
            return
        strokes = strokes.slice(0, -1)
        done.requestPaint()
    }

    function paintStroke(ctx, s) {
        ctx.strokeStyle = s.color
        ctx.fillStyle = s.color
        ctx.lineWidth = root.thick
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.beginPath()
        if (s.kind === "box") {
            ctx.rect(Math.min(s.a.x, s.b.x), Math.min(s.a.y, s.b.y), Math.abs(s.b.x - s.a.x), Math.abs(s.b.y - s.a.y))
            ctx.stroke()
            return
        }
        if (s.kind === "arrow") {
            const ang = Math.atan2(s.b.y - s.a.y, s.b.x - s.a.x)
            const head = 18
            ctx.moveTo(s.a.x, s.a.y)
            ctx.lineTo(s.b.x - Math.cos(ang) * head * 0.6, s.b.y - Math.sin(ang) * head * 0.6)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(s.b.x, s.b.y)
            ctx.lineTo(s.b.x - head * Math.cos(ang - 0.45), s.b.y - head * Math.sin(ang - 0.45))
            ctx.lineTo(s.b.x - head * Math.cos(ang + 0.45), s.b.y - head * Math.sin(ang + 0.45))
            ctx.closePath()
            ctx.fill()
            return
        }
        ctx.moveTo(s.pts[0].x, s.pts[0].y)
        for (let i = 1; i < s.pts.length; i++)
            ctx.lineTo(s.pts[i].x, s.pts[i].y)
        ctx.stroke()
    }

    Component.onCompleted: Store.drawView = root

    screen: Store.screenFor("draw")
    visible: Store.isOpen("draw")
    onVisibleChanged: {
        strokes = []
        live = null
        pen = 0
        done.requestPaint()
        current.requestPaint()
        if (visible)
            frame.forceActiveFocus()
    }
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.namespace: "torus-draw"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("draw") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: Store
        function onLockedChanged() {
            if (Store.locked)
                root.close()
        }
    }

    Item {
        id: frame
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier
            if (event.key === Qt.Key_Escape)
                root.close()
            else if (event.key === Qt.Key_Z && ctrl)
                root.undo()
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4)
                root.pen = event.key - Qt.Key_1
            else
                return
            event.accepted = true
        }

        Canvas {
            id: done
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                for (const s of root.strokes)
                    root.paintStroke(ctx, s)
            }
        }

        Canvas {
            id: current
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (root.live)
                    root.paintStroke(ctx, root.live)
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            width: hintRow.implicitWidth + 28
            height: hintRow.implicitHeight + 16
            radius: height / 2
            color: Qt.alpha(Theme.mantle, 0.92)
            border.width: 1
            border.color: Qt.alpha(Theme.surface1, 0.6)
            opacity: root.strokes.length === 0 && !root.live ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durMed } }
            Row {
                id: hintRow
                anchors.centerIn: parent
                spacing: Theme.sp6
                Row {
                    spacing: Theme.sp2
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: root.pens
                        Rectangle {
                            required property color modelData
                            required property int index
                            width: 14
                            height: 14
                            radius: 7
                            color: modelData
                            border.width: index === root.pen ? 2 : 0
                            border.color: Theme.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                KeyHints {
                    anchors.verticalCenter: parent.verticalCenter
                    hints: [["drag", "draw"], ["Shift drag", "arrow"], ["Ctrl drag", "box"], ["1 / 2 / 3 / 4", "color"], ["Ctrl Z", "undo"], ["Esc", "wipe and close"]]
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            onPressed: mouse => {
                const p = Qt.point(mouse.x, mouse.y)
                const c = String(root.pens[root.pen])
                if (mouse.modifiers & Qt.ShiftModifier)
                    root.live = { kind: "arrow", color: c, a: p, b: p }
                else if (mouse.modifiers & Qt.ControlModifier)
                    root.live = { kind: "box", color: c, a: p, b: p }
                else
                    root.live = { kind: "line", color: c, pts: [p] }
                current.requestPaint()
            }
            onPositionChanged: mouse => {
                const s = root.live
                if (!s)
                    return
                const p = Qt.point(mouse.x, mouse.y)
                if (s.kind === "line")
                    s.pts.push(p)
                else
                    s.b = p
                current.requestPaint()
            }
            onReleased: {
                const s = root.live
                root.live = null
                current.requestPaint()
                root.commit(s)
            }
        }
    }
}
