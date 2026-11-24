import QtQuick
import Quickshell.Widgets
import qs
import qs.components
import qs.services

Rectangle {
    id: root

    CoverSource { id: coverSrc; row: root.row }

    property var row: ({})
    property bool current: false
    property bool playing: false
    property bool starred: !!row.starred
    property int number: 0
    signal picked
    signal played
    signal queued
    signal menu(real x, real y)

    height: 48
    radius: Theme.rSm
    color: current ? Qt.alpha(Theme.accent, 0.16) : (hover.hovered ? Qt.alpha(Theme.surface1, 0.6) : "transparent")

    ClippingRectangle {
        id: art
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: root.row.kind === "artist" ? 18 : Theme.rXs + 3
        color: Theme.surface0
        Text {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: root.playing ? "󰎈" : (root.row.kind === "artist" ? "󰠃" : root.row.kind === "playlist" ? "󰲸" : root.row.kind === "album" ? "󰀥" : "󰎆")
            color: root.playing ? Theme.accent : Theme.overlay
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsLg
        }
        Image {
            id: cover
            anchors.fill: parent
            source: coverSrc.url
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 72
            visible: status === Image.Ready
        }
        Rectangle {
            anchors.fill: parent
            visible: root.playing && cover.status === Image.Ready
            color: Qt.alpha(Theme.crust, 0.55)
            Text { anchors.centerIn: parent; text: "󰎈"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsLg }
        }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 10
        anchors.right: right.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
            width: parent.width
            text: root.row.title || ""
            elide: Text.ElideRight
            color: root.playing ? Theme.accent : Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsMd
            font.weight: root.current || root.playing ? Font.DemiBold : Font.Normal
        }
        Text {
            width: parent.width
            text: root.row.kind === "track" ? [root.row.artist, root.row.album].filter(x => x).join(", ")
                : root.row.kind === "album" ? [root.row.artist, root.row.year || ""].filter(x => x).join(", ")
                : root.row.kind === "artist" ? "artist" : (root.row.count ? root.row.count + " songs" : "playlist")
            elide: Text.ElideRight
            color: Theme.overlay
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsXs
        }
    }

    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.sp4
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.starred
            text: "󰓎"
            color: Theme.yellow
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsMd
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.row.source && root.row.source !== "local"
            width: srcTag.implicitWidth + 10
            height: 16
            radius: 8
            color: Theme.surface0
            Text { id: srcTag; anchors.centerIn: parent; text: root.row.source || ""; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsXs }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.row.kind === "track" && !(hover.hovered || root.current)
            text: Music.fmt(root.row.seconds)
            color: Theme.overlay
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsXs
        }
        Rectangle {
            id: addBtn
            anchors.verticalCenter: parent.verticalCenter
            visible: (hover.hovered || root.current) && root.row.kind !== "artist"
            width: 26
            height: 26
            radius: 13
            color: addHover.hovered ? Theme.surface1 : "transparent"
            Text { anchors.centerIn: parent; text: "󰐕"; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: Theme.fsLg }
            HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
            Tap { onTapped: root.queued() }
        }
        Rectangle {
            id: playBtn
            anchors.verticalCenter: parent.verticalCenter
            visible: hover.hovered || root.current
            width: 26
            height: 26
            radius: 13
            color: playHover.hovered ? Theme.accent : Theme.surface0
            Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; text: "󰐊"; color: playHover.hovered ? Theme.crust : Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsLg }
            HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
            Tap { onTapped: root.played() }
        }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    Tap {
        quiet: playHover.hovered || addHover.hovered
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (point, button) => {
            if ((Store.over(playBtn, root, point.position)) || (Store.over(addBtn, root, point.position)))
                return
            if (button === Qt.RightButton) {
                root.picked()
                root.menu(point.position.x, point.position.y)
            } else {
                root.picked()
            }
        }
        onDoubleTapped: (point, button) => {
            if (button === Qt.LeftButton && !(Store.over(playBtn, root, point.position)))
                root.played()
        }
    }
}
