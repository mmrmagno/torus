import QtQuick
import qs
import qs.services

Row {
    id: root

    property int count: 12
    property real maxHeight: 14
    property real barWidth: 3
    property color tint: Theme.accent
    property bool live: true
    spacing: Theme.sp1
    visible: Visualizer.playing

    Repeater {
        model: root.count
        Rectangle {
            required property int index
            readonly property real v: {
                if (!root.live)
                    return 0.18
                const vals = Visualizer.values
                if (vals.length === 0)
                    return 0
                const i = Math.floor(index * vals.length / root.count)
                return vals[i] / 100
            }
            width: root.barWidth
            height: Math.max(2, v * root.maxHeight)
            radius: width / 2
            anchors.bottom: parent.bottom
            color: root.tint
            opacity: 0.55 + v * 0.45
            Behavior on height { NumberAnimation { duration: 60 } }
        }
    }
}
