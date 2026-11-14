import QtQuick
import QtQuick.Layouts
import qs
import qs.components

RowLayout {
    id: face

    property var info: ({})
    signal undo()
    spacing: Theme.sp5

    Text {
        text: "󰩹"
        color: Theme.accent
        font.family: Theme.fontMono
        font.pixelSize: Theme.fsXl
    }
    Text {
        Layout.fillWidth: true
        text: (face.info.count || 0) > 1 ? face.info.count + " files moved to the trash" : "Moved to the trash: " + (face.info.name || "")
        color: Theme.text
        elide: Text.ElideMiddle
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsMd
    }
    Rectangle {
        id: undoBtn
        implicitWidth: undoRow.implicitWidth + 18
        implicitHeight: 22
        radius: 11
        color: undoHover.hovered ? Theme.accent : Theme.surface0
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Row {
            id: undoRow
            anchors.centerIn: parent
            spacing: Theme.sp2
            Text { text: "󰕌"; color: undoHover.hovered ? Theme.crust : Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "Undo"; color: undoHover.hovered ? Theme.crust : Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; anchors.verticalCenter: parent.verticalCenter }
        }
        HoverHandler { id: undoHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: face.undo() }
    }
}
