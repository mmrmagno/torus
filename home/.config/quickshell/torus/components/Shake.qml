import QtQuick
import qs

SequentialAnimation {
    id: root

    required property Translate nudge
    property real by: 10

    function go() {
        if (Theme.motion > 0)
            restart()
        Store.sound("error")
        Store.shakes++
    }

    NumberAnimation { target: root.nudge; property: "x"; to: root.by; duration: 50 * Theme.motion }
    NumberAnimation { target: root.nudge; property: "x"; to: -root.by; duration: 80 * Theme.motion }
    NumberAnimation { target: root.nudge; property: "x"; to: root.by / 2; duration: 70 * Theme.motion }
    NumberAnimation { target: root.nudge; property: "x"; to: 0; duration: 60 * Theme.motion }
}
