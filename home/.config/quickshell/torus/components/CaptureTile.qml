import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
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
    property string badge: ""
    property bool starred: false
    property bool starrable: false
    property string caption: ""
    property bool cuttable: false
    property bool renamable: false
    property bool marked: false
    readonly property var actions: kind === "image" ? [["󰆏", "copy"], ["󰏫", "edit"], ["󰊄", "text"], ["󰉋", "folder"], ["󰆴", "delete"]] : (cuttable ? [["󰏫", "cut"]] : []).concat(renamable ? [["󰑕", "rename"]] : []).concat(starrable ? [[starred ? "󰓎" : "󰓒", "star"]] : []).concat([["󰆏", "copy"], ["󰉋", "folder"]]).concat(starred ? [] : [["󰆴", "delete"]])
    readonly property real picHeight: Math.max(0, height - 34)

    signal opened()
    signal thumbLost()
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
    border.width: tile.selected || tile.marked ? 2 : 1
    border.color: tile.marked ? Theme.green : (tileHover.hovered || tile.selected ? Theme.accent : Qt.alpha(Theme.surface1, 0.6))
    clip: true

    ClippingRectangle {
        id: picFrame
        x: 4
        y: 4
        width: tile.width - 8
        height: tile.picHeight - 4
        radius: Math.max(0, Theme.rCard - 4)
        color: Theme.crust
        Image {
            id: pic
            anchors.fill: parent
            source: tile.thumb ? "file://" + tile.thumb : ""
            sourceSize.width: 400
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            onStatusChanged: if (status === Image.Error) tile.thumbLost()
        }
    }
    Rectangle {
        visible: tile.badge !== ""
        x: picFrame.x + 6 + (actionRow.visible && tile.marked ? 28 : 0)
        y: actionRow.visible ? picFrame.y + picFrame.height - height - 8 : picFrame.y + 6
        z: 2
        width: badgeText.implicitWidth + 12
        height: 18
        radius: 9
        color: Qt.alpha(Theme.crust, 0.82)
        border.width: 1
        border.color: Qt.alpha(Theme.peach, 0.6)
        Text {
            id: badgeText
            anchors.centerIn: parent
            text: "AUTO · " + tile.badge.toUpperCase()
            color: Theme.peach
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsXs
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }
    }

    Rectangle {
        visible: tile.starred && !tileHover.hovered && !tile.selected
        anchors.right: picFrame.right
        anchors.top: picFrame.top
        anchors.margins: 6
        z: 2
        width: 22
        height: 22
        radius: 11
        color: Qt.alpha(Theme.crust, 0.82)
        Text { anchors.centerIn: parent; text: "󰓎"; color: Theme.yellow; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd }
    }

    Rectangle {
        visible: tile.marked
        anchors.left: picFrame.left
        anchors.bottom: picFrame.bottom
        anchors.margins: 6
        z: 2
        width: 22
        height: 22
        radius: 11
        color: Theme.green
        Text { anchors.centerIn: parent; text: "󰄬"; color: Theme.crust; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd }
    }

    Text {
        visible: pic.status !== Image.Ready
        anchors.centerIn: picFrame
        text: tile.kind === "video" ? "󰕧" : "󰋩"
        color: Theme.overlay
        font.family: Theme.fontMono
        font.pixelSize: 26
    }
    Rectangle {
        visible: tile.kind === "video"
        anchors.centerIn: picFrame
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
        Text { Layout.fillWidth: true; text: (tile.caption !== "" ? tile.caption + "  ·  " : "") + tile.ago(tile.time); color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsXs; elide: Text.ElideRight }
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
        id: actionRow
        visible: tileHover.hovered || tile.selected
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
