import QtQuick

Item {
    id: motion

    required property Item target
    property bool shown: false
    property real from: 0.96

    onShownChanged: if (shown) intro.restart()
    Component.onCompleted: if (shown) intro.restart()

    ParallelAnimation {
        id: intro
        NumberAnimation { target: motion.target; property: "opacity"; from: 0; to: 1; duration: 170; easing.type: Easing.OutCubic }
        NumberAnimation { target: motion.target; property: "scale"; from: motion.from; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }
}
