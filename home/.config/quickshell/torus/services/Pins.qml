pragma Singleton
import QtQuick
import Quickshell
import qs

Singleton {
    id: root

    property var list: []
    property int made: 0
    signal zoomed(int id, int steps)

    function pin(path) {
        if (!/\.(png|jpe?g|webp|bmp|gif|avif)$/i.test(path || ""))
            return false
        made++
        list = list.concat([{ id: made, path: path, screen: Store.focusedScreen }])
        return true
    }

    function zoom(id, steps) {
        zoomed(id, steps)
    }

    function isPin(t) {
        return /^torus-pin-[0-9]+$/.test((t && t.title) || "")
    }

    function close(id) {
        list = list.filter(p => p.id !== id)
    }
}
