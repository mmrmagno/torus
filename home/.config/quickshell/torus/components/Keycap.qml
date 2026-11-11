import QtQuick
import qs

Rectangle {
    property alias text: capText.text
    implicitWidth: capText.implicitWidth + 10
    implicitHeight: 18
    radius: 5
    color: Theme.surface0
    Text {
        id: capText
        anchors.centerIn: parent
        color: Theme.accent
        font.family: Theme.fontMono
        font.pixelSize: Theme.fsXs
    }
}
