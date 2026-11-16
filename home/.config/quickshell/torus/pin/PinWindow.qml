import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import "../components/fileuri.mjs" as U

FloatingWindow {
    id: win

    required property var modelData
    readonly property real roomW: modelData.screen ? modelData.screen.width : 1920
    readonly property real roomH: modelData.screen ? modelData.screen.height : 1080
    readonly property real natW: Math.max(1, pic.implicitWidth)
    readonly property real natH: Math.max(1, pic.implicitHeight)
    readonly property real fit: Math.min(1, roomW / 3 / natW, roomH / 3 / natH)
    property real zoom: 1

    function zoomBy(steps) {
        if (steps === 0)
            return
        const lo = 64 / (natW * fit)
        const hi = Math.min(roomW / (natW * fit), roomH / (natH * fit))
        zoom = Math.max(lo, Math.min(hi, zoom * Math.pow(1.1, steps)))
        Hyprland.dispatch('hl.dsp.window.resize({ x = ' + implicitWidth + ', y = ' + implicitHeight + ', window = "title:^' + title + '$" })')
    }

    screen: modelData.screen
    title: "torus-pin-" + modelData.id
    color: "transparent"
    visible: pic.status === Image.Ready
    implicitWidth: Math.round(natW * fit * zoom)
    implicitHeight: Math.round(natH * fit * zoom)

    Connections {
        target: Pins
        function onZoomed(id, steps) {
            if (id === win.modelData.id)
                win.zoomBy(steps)
        }
    }

    Image {
        id: pic
        anchors.fill: parent
        source: U.uriOf(win.modelData.path)
        sourceSize: Qt.size(win.roomW, win.roomH)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        cache: false
        onStatusChanged: if (status === Image.Error) Qt.callLater(Pins.close, win.modelData.id)
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Pins.close(win.modelData.id)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        property point from
        property bool moved: false
        onPressed: event => {
            from = Qt.point(event.x, event.y)
            moved = false
        }
        onPositionChanged: event => {
            if (pressed && !moved && Math.hypot(event.x - from.x, event.y - from.y) > 4) {
                moved = true
                win.startSystemMove()
            }
        }
        onDoubleClicked: Pins.close(win.modelData.id)
        onWheel: event => win.zoomBy(event.angleDelta.y > 0 ? 1 : (event.angleDelta.y < 0 ? -1 : 0))
    }
}
