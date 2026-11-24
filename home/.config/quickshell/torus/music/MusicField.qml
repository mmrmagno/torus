import QtQuick
import qs

Rectangle {
    id: root

    property string label: ""
    property string hint: ""
    property alias text: input.text
    property bool secret: false
    property alias editor: input
    signal submitted

    implicitHeight: 34
    radius: Theme.rSm
    color: Theme.surface0
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? Theme.accent : Qt.alpha(Theme.overlay, 0.3)

    Text {
        id: cap
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 72
        text: root.label
        color: Theme.subtext
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSm
    }
    TextInput {
        id: input
        anchors.left: cap.right
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Theme.text
        echoMode: root.secret ? TextInput.Password : TextInput.Normal
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsMd
        selectByMouse: true
        activeFocusOnTab: true
        Keys.onReturnPressed: root.submitted()
        Keys.onEnterPressed: root.submitted()
        Text {
            visible: input.text === ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.hint
            color: Theme.overlay
            font: input.font
        }
    }
}
