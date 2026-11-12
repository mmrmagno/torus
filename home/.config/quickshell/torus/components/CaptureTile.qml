import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: tile

    property string path: ""
    property string kind: "image"
    property string thumb: ""
    property real time: 0
    property real bytes: 0
    property bool selected: false
    property bool armed: false
    readonly property var actions: kind === "image" ? [["󰆏", "copy"], ["󰏫", "edit"], ["󰊄", "text"], ["󰉋", "folder"], ["󰆴", "delete"]] : [["󰆏", "copy"], ["󰉋", "folder"], ["󰆴", "delete"]]
    readonly property real picHeight: Math.max(0, height - 34)

    signal opened()
    signal act(string what)

    function ago(t) {
        const m = Math.floor((Date.now() / 1000 - t) / 60)
        if (m < 1)
            return "just now"
        if (m < 60)
            return m + " min ago"
        if (m < 1440)
            return Math.floor(m / 60) + " h ago"
        return Qt.formatDate(new Date(t * 1000), "d MMM")
    }

    function size(b) {
        return b > 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB"
    }

    radius: Theme.rCard
    color: Theme.mantle
    border.width: tile.selected ? 2 : 1
    border.color: tileHover.hovered || tile.selected ? Theme.accent : Qt.alpha(Theme.surface1, 0.6)
    clip: true

    Image {
        id: pic
        x: 4
        y: 4
        width: tile.width - 8
        height: tile.picHeight - 4
        source: tile.thumb ? "file://" + tile.thumb : ""
        sourceSize.width: 400
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
    Text {
        visible: pic.status !== Image.Ready
        anchors.centerIn: pic
        text: tile.kind === "video" ? "󰕧" : "󰋩"
        color: Theme.overlay
        font.family: Theme.fontMono
        font.pixelSize: 26
    }
    Rectangle {
        visible: tile.kind === "video"
        anchors.centerIn: pic
        width: 34
        height: 34
        radius: 17
        color: Qt.alpha(Theme.crust, 0.7)
        Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; text: "󰐊"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsXl }
    }
    RowLayout {
        anchors.left: tile.left
        anchors.right: tile.right
        anchors.bottom: tile.bottom
        anchors.margins: 8
        spacing: Theme.sp2
        Text { Layout.fillWidth: true; text: tile.ago(tile.time); color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsXs; elide: Text.ElideRight }
        Text { visible: tile.bytes > 0; text: tile.size(tile.bytes); color: Theme.overlay; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs }
    }

    HoverHandler {
        id: tileHover
        onHoveredChanged: if (!hovered && tile.armed) tile.act("disarm")
    }
    MouseArea {
        anchors.fill: tile
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.opened()
    }

    Row {
        visible: tileHover.hovered
        anchors.right: tile.right
        anchors.top: tile.top
        anchors.margins: 8
        spacing: 4
        Repeater {
            model: tile.actions
            Rectangle {
                id: mini
                required property var modelData
                readonly property bool danger: modelData[1] === "delete"
                readonly property bool armedHere: danger && tile.armed
                width: 26
                height: 26
                radius: 13
                color: miniHover.containsMouse || armedHere ? (danger ? Theme.red : Theme.accent) : Qt.alpha(Theme.crust, 0.8)
                Text {
                    anchors.centerIn: mini
                    text: mini.armedHere ? "󰄬" : mini.modelData[0]
                    color: miniHover.containsMouse || mini.armedHere ? Theme.crust : Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsMd
                }
                MouseArea {
                    id: miniHover
                    anchors.fill: mini
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tile.act(mini.modelData[1])
                }
            }
        }
    }
}
