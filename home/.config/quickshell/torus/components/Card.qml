import QtQuick
import qs

Rectangle {
    id: root

    default property alias content: inner.data
    property string title: ""
    property string status: "ready"
    property string statusText: ""
    property bool retryable: true
    signal retry

    radius: Theme.rCard
    color: Qt.alpha(Theme.surface0, 0.7)
    border.width: 1
    border.color: Qt.alpha(Theme.surface1, 0.6)

    Text {
        id: heading
        visible: root.title !== ""
        text: root.title
        x: 14
        y: 10
        color: Theme.overlay
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSm
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: heading.visible ? 30 : 14
        opacity: root.status === "ready" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }

    CardState {
        anchors.fill: inner
        status: root.status
        text: root.statusText
        retryable: root.retryable
        onRetry: root.retry()
    }
}
