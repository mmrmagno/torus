import QtQuick
import qs

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool active: false
    signal clicked

    activeFocusOnTab: visible
    onActiveFocusChanged: if (activeFocus) Store.focusLabel = label || icon
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
    implicitWidth: row.implicitWidth + 24
    implicitHeight: 34
    radius: Theme.radius
    color: active ? Theme.accent : (hover.hovered ? Theme.surface1 : Theme.surface0)
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.sp3
        Text {
            text: root.icon
            visible: root.icon !== ""
            color: root.active ? Theme.crust : Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: Theme.icon
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.label
            visible: root.label !== ""
            color: root.active ? Theme.crust : Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsMd
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    FocusRing { on: root.activeFocus; baseRadius: root.radius }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: root.clicked() }
    scale: tap.pressed ? 0.95 : 1
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }
}
