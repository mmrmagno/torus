import QtQuick
import qs

Rectangle {
    default property alias content: inner.data
    property string title: ""
    radius: Theme.rCard
    color: Qt.alpha(Theme.surface0, 0.7)
    border.width: 1
    border.color: Qt.alpha(Theme.surface1, 0.6)

    Text {
        id: heading
        visible: parent.title !== ""
        text: parent.title
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
    }
}
