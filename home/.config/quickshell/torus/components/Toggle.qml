import QtQuick
import qs

Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 40
    implicitHeight: 22
    radius: height / 2
    color: checked ? Theme.accent : (hover.hovered ? Theme.surface1 : Theme.surface0)
    border.width: 1
    border.color: checked ? Theme.accent : Theme.surface1
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.crust : Theme.subtext
        Behavior on x { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.toggled(!root.checked) }
}
