import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: row

    property string glyph: "●"
    property color tint: Theme.green
    property string title: ""
    property string sub: ""
    property bool clickable: false
    signal clicked

    Layout.fillWidth: true
    implicitHeight: 40
    radius: Theme.rSm
    color: row.clickable && hover.hovered ? Theme.surface0 : "transparent"

    HoverHandler { id: hover; enabled: row.clickable; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: row.clickable; onTapped: row.clicked() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: Theme.sp5
        Text { text: row.glyph; color: row.tint; font.family: Theme.fontMono; font.pixelSize: Theme.fsLg }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { Layout.fillWidth: true; text: row.title; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsBase; elide: Text.ElideRight }
            Text { Layout.fillWidth: true; visible: row.sub !== ""; text: row.sub; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsXs; elide: Text.ElideRight }
        }
    }
}
