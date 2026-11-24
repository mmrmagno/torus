import QtQuick
import Quickshell
import qs

Item {
    id: motion

    required property Item target
    property bool shown: false
    property string name: ""
    property real from: 0.96
    property bool fresh: true
    property real p: 0
    property real flow: 1000
    property real reach: from
    // not tied to shown: the window reads this in the same breath as its open flag, and a gap there unmaps it
    readonly property bool leaving: p > 0
    readonly property real eased: 1 - Math.pow(1 - p, 3)

    onShownChanged: run()
    Component.onCompleted: {
        target.transform = [zoom]
        if (name !== "")
            Store.motions[name] = () => p.toFixed(2) + "|" + Math.round(zoom.origin.x) + "," + Math.round(zoom.origin.y) + "|" + reach.toFixed(2) + "|" + Math.round(target.width)
        if (shown)
            run()
    }

    property string at: ""

    function run() {
        const scr = name !== "" ? Store.screenFor(name) : null
        const where = scr ? scr.name : ""
        // turned around before it unmapped: the window must still do what it does on every open
        if (shown && p > 0 && fresh && where === at && target.QsWindow.window)
            target.QsWindow.window.visibleChanged()
        if (shown && (p === 0 || where !== at)) {
            p = 0
            at = where
            start()
        }
        const left = Math.abs((shown ? 1 : 0) - p)
        move.stop()
        if (Theme.motion === 0 || left === 0) {
            p = shown ? 1 : 0
            return
        }
        move.to = shown ? 1 : 0
        move.duration = Math.round((shown ? Theme.durEnter : Theme.durExit) * left)
        move.start()
    }

    function start() {
        aim()
        if (Theme.motion > 0) {
            flow = 0
            wave.restart()
        }
    }

    Connections {
        target: motion.target
        function onWidthChanged() { if (motion.p < 0.5) motion.aim() }
        function onHeightChanged() { if (motion.p < 0.5) motion.aim() }
    }

    function aim() {
        const w = target.width, h = target.height
        const at = name !== "" ? Store.originFor(name, target) : null
        reach = at ? Math.min(from, 0.9) : from
        switch (target.transformOrigin) {
        case Item.Top: zoom.origin.x = w / 2; zoom.origin.y = 0; break
        case Item.TopRight: zoom.origin.x = w; zoom.origin.y = 0; break
        default: zoom.origin.x = w / 2; zoom.origin.y = h / 2
        }
        if (at) {
            zoom.origin.x = at.x
            zoom.origin.y = at.y
        }
    }

    function arrive(i) {
        return Theme.motion === 0 ? 1 : Math.max(0, Math.min(1, (flow - Math.min(i, 12) * 20) / 140))
    }

    Binding { target: motion.target; property: "opacity"; value: Math.min(1, motion.eased * 1.15) }

    Scale {
        id: zoom
        xScale: motion.reach + (1 - motion.reach) * motion.eased
        yScale: xScale
    }

    NumberAnimation { id: move; target: motion; property: "p" }
    NumberAnimation { id: wave; target: motion; property: "flow"; from: 0; to: 400; duration: 400 * Theme.motion }
}
