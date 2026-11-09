import QtQuick
import qs

Item {
    id: motion

    required property Item target
    property bool shown: false
    property real from: 0.96
    property bool leaving: false

    onShownChanged: {
        if (shown) {
            outro.stop()
            leaving = false
            intro.restart()
        } else if (Theme.motion > 0 && target) {
            intro.stop()
            leaving = true
            outro.restart()
        }
    }
    Component.onCompleted: if (shown) intro.restart()

    ParallelAnimation {
        id: intro
        NumberAnimation { target: motion.target; property: "opacity"; from: 0; to: 1; duration: Theme.durMed; easing.type: Easing.OutCubic }
        NumberAnimation { target: motion.target; property: "scale"; from: motion.from; to: 1; duration: Theme.durSlow; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }

    ParallelAnimation {
        id: outro
        NumberAnimation { target: motion.target; property: "opacity"; to: 0; duration: Theme.durFast; easing.type: Easing.InCubic }
        NumberAnimation { target: motion.target; property: "scale"; to: (1 + motion.from) / 2; duration: Theme.durFast; easing.type: Easing.InCubic }
        onFinished: motion.leaving = false
    }
}
