import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    property point a: Qt.point(0, 0)
    property point b: Qt.point(0, 0)
    property point cursor: Qt.point(-100, -100)
    property bool dragging: false
    property bool measured: false
    property bool lineMode: false
    property bool straight: false
    property point raw: Qt.point(0, 0)
    property string hex: ""
    property bool sampled: false
    readonly property real k: shot.sourceSize.width > 0 && width > 0 ? shot.sourceSize.width / width : 1
    readonly property int pw: Math.round(Math.abs(b.x - a.x) * k)
    readonly property int ph: Math.round(Math.abs(b.y - a.y) * k)
    readonly property real dist: Math.sqrt(pw * pw + ph * ph)
    readonly property real angle: Math.atan2(-(b.y - a.y), b.x - a.x) * 180 / Math.PI

    function rgb(h) {
        const n = parseInt(h.slice(1), 16)
        return [(n >> 16) & 255, (n >> 8) & 255, n & 255]
    }

    function sample(x, y) {
        if (!sampled)
            return
        const sx = Math.max(0, Math.min(sampler.width - 1, Math.round(x * k)))
        const sy = Math.max(0, Math.min(sampler.height - 1, Math.round(y * k)))
        const d = sampler.getContext("2d").getImageData(sx, sy, 1, 1).data
        hex = "#" + [d[0], d[1], d[2]].map(v => v.toString(16).padStart(2, "0")).join("")
    }

    function copy(text, what) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", text])
        Store.rulerLast = what + ":" + text
        Island.flash("osd", { icon: what === "color" ? "󰏘" : "󰆾", label: text + "  ·  copied", value: -1 }, 2200)
    }

    function finish() {
        dragging = false
        if (pw < 2 && ph < 2)
            return
        measured = true
        copy(lineMode ? Math.round(dist) + " px" : pw + "x" + ph, lineMode ? "distance" : "size")
    }

    function track() {
        if (!lineMode || !straight) {
            b = raw
            return
        }
        const dx = raw.x - a.x
        const dy = raw.y - a.y
        const step = Math.PI / 4
        const t = Math.round(Math.atan2(dy, dx) / step) * step
        const len = dx * Math.cos(t) + dy * Math.sin(t)
        b = Qt.point(Math.round(a.x + len * Math.cos(t)), Math.round(a.y + len * Math.sin(t)))
    }

    onStraightChanged: if (dragging) track()

    function close() {
        Store.setOpen("ruler", false)
    }

    Component.onCompleted: Store.rulerView = root

    screen: Store.screenFor("ruler")
    visible: Store.isOpen("ruler")
    onVisibleChanged: if (visible) {
        measured = false
        dragging = false
        sampled = false
        hex = ""
        sampler.loadImage(shot.source)
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
    WlrLayershell.namespace: "torus-ruler"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("ruler") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        id: frame
        anchors.fill: parent
        focus: true
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Control)
                root.straight = false
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Control)
                root.straight = true
            else if (event.key === Qt.Key_Escape)
                root.close()
            else if (event.key === Qt.Key_C && root.hex !== "")
                root.copy(root.hex, "color")
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.close()
            else
                return
            event.accepted = true
        }

        Image {
            id: shot
            anchors.fill: parent
            source: Store.rulerShot !== "" ? "file://" + Store.rulerShot : ""
            cache: false
            asynchronous: false
        }

        Canvas {
            id: sampler
            visible: false
            width: Math.max(1, shot.sourceSize.width)
            height: Math.max(1, shot.sourceSize.height)
            onImageLoaded: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.drawImage(shot.source, 0, 0)
                root.sampled = true
                root.sample(root.cursor.x, root.cursor.y)
            }
        }

        Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.crust, 0.18) }

        Rectangle { x: 0; y: root.cursor.y; width: parent.width; height: 1; color: Qt.alpha(Theme.accent, 0.55); visible: !root.dragging }
        Rectangle { x: root.cursor.x; y: 0; width: 1; height: parent.height; color: Qt.alpha(Theme.accent, 0.55); visible: !root.dragging }

        Rectangle {
            visible: (root.dragging || root.measured) && !root.lineMode
            x: Math.min(root.a.x, root.b.x)
            y: Math.min(root.a.y, root.b.y)
            width: Math.abs(root.b.x - root.a.x)
            height: Math.abs(root.b.y - root.a.y)
            color: Qt.alpha(Theme.accent, 0.12)
            border.width: 1
            border.color: Theme.accent
        }

        Shape {
            anchors.fill: parent
            visible: (root.dragging || root.measured) && root.lineMode
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.accent
                strokeWidth: 2
                fillColor: "transparent"
                startX: root.a.x
                startY: root.a.y
                PathLine { x: root.b.x; y: root.b.y }
            }
        }

        Rectangle {
            visible: root.dragging || root.measured
            x: Math.min(parent.width - width - 8, root.b.x + 14)
            y: Math.min(parent.height - height - 8, root.b.y + 14)
            width: measureText.implicitWidth + 16
            height: 26
            radius: 13
            color: Qt.alpha(Theme.mantle, 0.92)
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.5)
            Text {
                id: measureText
                anchors.centerIn: parent
                text: root.lineMode ? Math.round(root.dist) + " px  ·  " + Math.round(root.angle) + "°  (" + root.pw + " × " + root.ph + ")" : root.pw + " × " + root.ph
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsSm
            }
        }

        Rectangle {
            visible: !root.dragging && root.hex !== ""
            x: Math.min(parent.width - width - 8, root.cursor.x + 16)
            y: Math.max(8, root.cursor.y - height - 12)
            width: colorRow.implicitWidth + 16
            height: 30
            radius: 15
            color: Qt.alpha(Theme.mantle, 0.92)
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.5)
            Row {
                id: colorRow
                anchors.centerIn: parent
                spacing: Theme.sp4
                Rectangle { width: 16; height: 16; radius: 4; color: root.hex || "transparent"; border.width: 1; border.color: Qt.alpha(Theme.text, 0.3); anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.hex === "" ? "" : root.hex + "  rgb(" + root.rgb(root.hex).join(", ") + ")  ·  C copies"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsSm
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            width: hint.implicitWidth + 28
            height: hint.implicitHeight + 16
            radius: height / 2
            color: Qt.alpha(Theme.mantle, 0.92)
            border.width: 1
            border.color: Qt.alpha(Theme.surface1, 0.6)
            KeyHints {
                id: hint
                anchors.centerIn: parent
                hints: [["drag", "box"], ["Shift drag", "distance"], ["Shift Ctrl drag", "straight line"], ["C", "copy color"], ["Esc", "close"]]
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.CrossCursor
            onPositionChanged: mouse => {
                root.cursor = Qt.point(mouse.x, mouse.y)
                root.straight = (mouse.modifiers & Qt.ControlModifier) !== 0
                if (pressed) {
                    root.raw = Qt.point(mouse.x, mouse.y)
                    root.track()
                }
                else
                    root.sample(mouse.x, mouse.y)
            }
            onPressed: mouse => {
                root.lineMode = (mouse.modifiers & Qt.ShiftModifier) !== 0
                root.a = Qt.point(mouse.x, mouse.y)
                root.raw = root.a
                root.b = root.a
                root.measured = false
                root.dragging = true
            }
            onReleased: root.finish()
        }
    }
}
