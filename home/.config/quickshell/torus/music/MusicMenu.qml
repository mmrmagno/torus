import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    property var items: []
    property int index: 0
    signal chosen(string what)
    signal dismissed

    function key(event) {
        if (event.key === Qt.Key_Escape)
            dismissed()
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
            index = Math.min(items.length - 1, index + 1)
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
            index = Math.max(0, index - 1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
            chosen(items[index][0])
        else
            return false
        return true
    }

    width: 210
    height: col.implicitHeight + 12
    radius: Theme.rSm + 2
    color: Theme.mantle
    border.width: 1
    border.color: Qt.alpha(Theme.accent, 0.35)

    Column {
        id: col
        x: 6
        y: 6
        width: parent.width - 12
        Repeater {
            model: root.items
            Rectangle {
                id: item
                required property var modelData
                required property int index
                width: col.width
                height: 30
                radius: Theme.rXs + 2
                color: item.index === root.index ? Qt.alpha(Theme.accent, 0.18) : "transparent"
                Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: item.modelData[1]; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd }
                Text { x: 32; anchors.verticalCenter: parent.verticalCenter; text: item.modelData[2]; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                Text { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: item.modelData[3] || ""; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsXs }
                HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.index = item.index }
                Tap { onTapped: root.chosen(item.modelData[0]) }
            }
        }
    }
}
