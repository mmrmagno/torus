import QtQuick
import qs

QtObject {
    id: root

    property Item target
    property bool down: false
    // the same few pixels on a small button and on a wide row
    property real depth: 5
    readonly property real to: target ? Math.max(0.88, Math.min(0.99, 1 - depth / Math.max(1, target.width, target.height))) : 1
    property real size: down ? to : 1

    Behavior on size { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
    onSizeChanged: if (target) target.scale = size
}
