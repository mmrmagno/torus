import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.components
import qs.services

Rectangle {
    id: root

    CoverSource { id: coverSrc; row: root.track }

    readonly property alias cover: npCover
    readonly property alias coverUrl: npArt.source
    readonly property var track: Music.current
    readonly property var out: Music.voice
    readonly property real part: Music.duration > 0 ? Math.max(0, Math.min(1, Music.time / Music.duration)) : 0
    signal openQueue
    Binding { target: Store; property: "songPart"; value: root.part }

    implicitHeight: 64

    Component.onCompleted: Store.musicVol = () => {
        const p = vol.mapToItem(null, vol.width / 2, vol.height / 2)
        return Math.round(root.out.volume * 100) + "|" + (root.out.muted ? "muted" : "on") + "|" + (Music.node ? "stream" : "idle") + "|" + Math.round(p.x) + "," + Math.round(p.y) + "," + vol.width
    }
    radius: Theme.rCard
    color: Qt.alpha(Theme.crust, 0.45)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 12
        spacing: Theme.sp6

        ClippingRectangle {
            id: npCover
            opacity: Fly.on && Fly.name === "music" ? 0 : 1
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: Theme.rSm
            color: Theme.surface0
            Text {
                anchors.centerIn: parent
                visible: npArt.status !== Image.Ready
                text: "󰎆"
                color: Theme.overlay
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsXl
            }
            Image {
                id: npArt
                anchors.fill: parent
                source: coverSrc.url
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 88
                visible: status === Image.Ready
            }
            Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.crust, 0.35); visible: npHover.hovered; Text { anchors.centerIn: parent; text: "󰲹"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsXl } }
            HoverHandler { id: npHover; cursorShape: Qt.PointingHandCursor }
            Tap { onTapped: root.openQueue() }
        }

        ColumnLayout {
            Layout.preferredWidth: 220
            Layout.maximumWidth: 260
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: root.track ? root.track.title : "Nothing playing"
                elide: Text.ElideRight
                color: root.track ? Theme.text : Theme.overlay
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsMd
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: root.track ? [root.track.artist, root.track.source === "local" ? "" : root.track.source].filter(x => x).join(", ") : "Enter on anything plays it"
                elide: Text.ElideRight
                color: Theme.overlay
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsXs
            }
        }

        Row {
            spacing: Theme.sp2
            Repeater {
                model: [["󰒮", "prev"], [Music.paused ? "󰐊" : "󰏤", "toggle"], ["󰒭", "skip"]]
                Rectangle {
                    id: ctl
                    required property var modelData
                    width: 34
                    height: 34
                    radius: 17
                    color: ctlHover.hovered ? Theme.surface1 : (modelData[1] === "toggle" ? Theme.surface0 : "transparent")
                    ProgressRing {
                        visible: ctl.modelData[1] === "toggle" && !!root.track && Music.duration > 0
                        anchors.fill: parent
                        anchors.margins: -5
                        value: root.part
                    }
                    Text { anchors.centerIn: parent; text: ctl.modelData[0]; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsXl }
                    HoverHandler { id: ctlHover; cursorShape: Qt.PointingHandCursor }
                    Tap { onTapped: Music.control(ctl.modelData[1]) }
                }
            }
        }

        Text {
            text: Music.fmt(Music.time)
            color: Theme.overlay
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsXs
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: 18
            Rectangle {
                id: bar
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: seekHover.hovered && root.track ? 6 : 4
                radius: height / 2
                color: Theme.surface0
                Behavior on height { NumberAnimation { duration: Theme.durFast } }
                Rectangle {
                    width: bar.width * root.part
                    height: parent.height
                    radius: height / 2
                    color: Theme.accent
                }
            }
            HoverHandler { id: seekHover; cursorShape: root.track ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler {
                onTapped: point => {
                    if (Music.duration > 0)
                        Music.act(["seek", String(Math.floor(point.position.x / bar.width * Music.duration))])
                }
            }
        }
        Text {
            text: Music.fmt(Music.duration)
            color: Theme.overlay
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsXs
        }
        Rectangle {
            visible: !!root.track && root.track.source !== "local"
            width: 30
            height: 30
            radius: 15
            color: starHover.hovered ? Theme.surface1 : "transparent"
            Text { anchors.centerIn: parent; text: root.track && root.track.starred ? "󰓎" : "󰓒"; color: root.track && root.track.starred ? Theme.yellow : Theme.subtext; font.family: Theme.fontMono; font.pixelSize: Theme.fsLg }
            HoverHandler { id: starHover; cursorShape: Qt.PointingHandCursor }
            Tap { onTapped: Music.control("star") }
        }
        Rectangle {
            width: 30
            height: 30
            radius: 15
            color: muteHover.hovered ? Theme.surface1 : "transparent"
            Text {
                anchors.centerIn: parent
                text: root.out.muted ? "󰝟" : root.out.volume < 0.34 ? "󰕿" : root.out.volume < 0.67 ? "󰖀" : "󰕾"
                color: root.out.muted ? Theme.overlay : Theme.subtext
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsLg
            }
            HoverHandler { id: muteHover; cursorShape: Qt.PointingHandCursor }
            Tap { onTapped: root.out.muted = !root.out.muted }
        }
        VolumeSlider {
            id: vol
            Layout.preferredWidth: 110
            audio: root.out
            most: 1
            activeFocusOnTab: false
        }
        Text {
            Layout.preferredWidth: 34
            text: Math.round(root.out.volume * 100) + "%"
            horizontalAlignment: Text.AlignRight
            color: Theme.overlay
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsXs
            font.features: { "tnum": 1 }
        }
    }
}
