import QtQuick
import qs

Rectangle {
    property alias hints: pillHints.hints
    width: pillHints.implicitWidth + 28
    height: pillHints.implicitHeight + 16
    radius: height / 2
    color: Qt.alpha(Theme.mantle, 0.92)
    border.width: 1
    border.color: Qt.alpha(Theme.surface1, 0.6)
    KeyHints {
        id: pillHints
        anchors.centerIn: parent
    }
}
