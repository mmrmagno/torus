import QtQuick
import qs

Item {
    id: root

    property string status: "ready"
    property string text: ""
    property bool retryable: true
    signal retry

    visible: opacity > 0
    opacity: status === "ready" ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

    Row {
        id: dots
        anchors.centerIn: parent
        visible: root.status === "loading"
        spacing: Theme.sp3
        Repeater {
            model: 3
            Rectangle {
                id: dot
                required property int index
                width: 6
                height: 6
                radius: 3
                color: Theme.accent
                opacity: 0.25
                SequentialAnimation on opacity {
                    running: dots.visible && root.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: dot.index * 160 }
                    NumberAnimation { to: 1; duration: 320; easing.type: Easing.OutCubic }
                    NumberAnimation { to: 0.25; duration: 480; easing.type: Easing.InCubic }
                    PauseAnimation { duration: (2 - dot.index) * 160 }
                }
            }
        }
    }

    Text {
        anchors.top: dots.bottom
        anchors.topMargin: Theme.sp4
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.status === "loading" && root.text !== ""
        text: root.text
        color: Theme.overlay
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSm
    }

    Column {
        anchors.centerIn: parent
        width: parent.width
        visible: root.status === "empty" || root.status === "error"
        spacing: Theme.sp4
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            text: (root.status === "error" ? "󰀦  " : "") + (root.text || (root.status === "error" ? "could not load" : "nothing here yet"))
            color: root.status === "error" ? Theme.peach : Theme.overlay
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsMd
        }
        PanelButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.status === "error" && root.retryable
            implicitHeight: 28
            icon: "󰑓"
            label: "Retry"
            onClicked: root.retry()
        }
    }
}
