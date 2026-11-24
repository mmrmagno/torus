import QtQuick
import Quickshell.Widgets
import qs
import qs.components
import qs.services

Item {
    id: root

    CoverSource { id: coverSrc; row: root.row }

    property var row: ({})
    property bool current: false
    property int size: 150
    signal picked
    signal opened
    signal played

    width: size
    height: size + 42

    ClippingRectangle {
        id: art
        width: root.size
        height: root.size
        radius: root.row.kind === "artist" ? root.size / 2 : Theme.rCard
        color: Theme.surface0
        scale: press.pressed && !playHover.hovered ? 0.98 : root.current ? 1.03 : (hover.hovered ? 1.015 : 1)
        Behavior on scale { NumberAnimation { duration: Theme.durFast } }

        Text {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: root.row.kind === "artist" ? "󰠃" : (root.row.kind === "playlist" ? "󰲸" : "󰀥")
            color: Theme.overlay
            font.family: Theme.fontMono
            font.pixelSize: Math.round(root.size / 3)
        }
        Image {
            id: cover
            anchors.fill: parent
            source: coverSrc.url
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 300
            visible: status === Image.Ready
        }
        Rectangle {
            id: playBtn
            visible: hover.hovered || root.current
            z: 6
            x: art.width - width - 8
            y: art.height - height - 8
            width: 34
            height: 34
            radius: 17
            color: playHover.hovered ? Theme.accent : Qt.alpha(Theme.crust, 0.82)
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; text: "󰐊"; color: playHover.hovered ? Theme.crust : Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsXl }
            HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
            Tap { onTapped: root.played() }
        }
        Rectangle {
            anchors.fill: parent
            z: 7
            radius: art.radius
            color: "transparent"
            border.width: root.current ? 3 : (hover.hovered ? 1 : 0)
            border.color: root.current ? Theme.accent : Qt.alpha(Theme.accent, 0.5)
        }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: press
            acceptedButtons: Qt.LeftButton
            onTapped: (point, button) => {
                if (Store.over(playBtn, art, point.position))
                    return
                root.current ? root.opened() : root.picked()
            }
            onDoubleTapped: (point, button) => {
                if (!(Store.over(playBtn, art, point.position)))
                    root.played()
            }
        }
    }
    Text {
        anchors.top: art.bottom
        anchors.topMargin: 6
        width: root.size
        text: root.row.title || ""
        horizontalAlignment: root.row.kind === "artist" ? Text.AlignHCenter : Text.AlignLeft
        elide: Text.ElideRight
        color: root.current ? Theme.text : Theme.subtext
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSm
        font.weight: Font.DemiBold
    }
    Text {
        anchors.top: art.bottom
        anchors.topMargin: 22
        width: root.size
        text: root.row.kind === "album" ? (root.row.artist || "") + (root.row.year ? ", " + root.row.year : "")
            : root.row.kind === "artist" ? (root.row.count ? root.row.count + (root.row.count === 1 ? " album" : " albums") : "")
            : (root.row.count ? root.row.count + " songs" : "")
        horizontalAlignment: root.row.kind === "artist" ? Text.AlignHCenter : Text.AlignLeft
        elide: Text.ElideRight
        color: Theme.overlay
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsXs
    }
    Rectangle {
        visible: root.row.source && root.row.source !== "local"
        x: 8
        y: 8
        z: 8
        width: tag.implicitWidth + 10
        height: 16
        radius: 8
        color: Qt.alpha(Theme.crust, 0.8)
        Text { id: tag; anchors.centerIn: parent; text: root.row.source || ""; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsXs }
    }
}
