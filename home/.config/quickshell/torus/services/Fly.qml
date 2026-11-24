pragma Singleton
import QtQuick
import Quickshell
import qs

Singleton {
    id: root

    property bool on: false
    property bool moving: false
    property string name: ""
    property url art: ""
    property string screenName: ""
    property var start: null
    property var end: null
    property real p: 0
    property int count: 0

    function box(item, r) {
        return boxIn(item, item, r)
    }

    // frame is mapped without the zoom PanelMotion puts on it
    function boxIn(item, frame, r) {
        const q = item === frame ? { x: 0, y: 0 } : item.mapToItem(frame, 0, 0)
        const a = Store.placeOf(frame.parent, frame.x + q.x, frame.y + q.y)
        return a ? { x: a.x, y: a.y, w: item.width, h: item.height, r: r, screen: a.screen } : null
    }

    function go(what, url, a, b) {
        cancel()
        if (Theme.motion === 0 || !a || !b || a.screen !== b.screen || String(url) === "")
            return false
        name = what
        art = url
        start = a
        end = b
        screenName = a.screen
        p = 0
        on = true
        guard.restart()
        return true
    }

    function shown() {
        if (!on || moving)
            return
        moving = true
        count++
        move.restart()
    }

    function cancel() {
        guard.stop()
        move.stop()
        moving = false
        on = false
        name = ""
    }

    // a screen that never shows the surface must not leave a cover hidden
    Timer {
        id: guard
        interval: 900
        onTriggered: root.cancel()
    }

    NumberAnimation {
        id: move
        target: root
        property: "p"
        from: 0
        to: 1
        duration: Theme.durEnter
        easing.type: Easing.InOutCubic
        onFinished: root.cancel()
    }
}
