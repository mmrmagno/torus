import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.components
import qs.services

Rectangle {
    id: root

    readonly property var player: Mpris.players.values.length > 0 ? (Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0]) : null
    readonly property string art: player ? player.trackArtUrl : ""
    readonly property color tint: quant.colors.length > 0 ? quant.colors[0] : Theme.accent

    visible: player !== null
    implicitHeight: 132
    radius: Theme.radius
    color: Theme.surface0
    clip: true

    ColorQuantizer {
        id: quant
        source: root.art
        depth: 1
        rescaleSize: 64
    }

    Timer {
        running: root.visible && root.player && root.player.isPlaying
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Image {
        id: bg
        anchors.fill: parent
        source: root.art
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: bg
        visible: root.art !== ""
        blurEnabled: true
        blur: 1
        blurMax: 48
        brightness: -0.35
        saturation: 0.2
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.base, 0.45)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        Rectangle {
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            radius: 10
            color: Theme.mantle
            clip: true
            Image {
                anchors.fill: parent
                source: root.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                visible: root.art === ""
                text: "󰎆"
                color: root.tint
                font.family: Theme.fontMono
                font.pixelSize: 36
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                Layout.fillWidth: true
                text: root.player ? root.player.trackTitle : ""
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: 15
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.player ? root.player.trackArtist : ""
                color: Theme.subtext
                font.family: Theme.fontUi
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: Lyrics.line !== ""
                text: Lyrics.line
                color: root.tint
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.italic: true
                elide: Text.ElideRight
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: 6
                visible: root.player && root.player.lengthSupported
                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: Qt.alpha(Theme.text, 0.15)
                }
                Rectangle {
                    width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                    height: parent.height
                    radius: 3
                    color: root.tint
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (root.player && root.player.canSeek)
                            root.player.position = root.player.length * mouse.x / width
                    }
                }
            }

            RowLayout {
                spacing: 6
                PanelButton { icon: "󰒮"; onClicked: root.player.previous() }
                PanelButton { icon: root.player && root.player.isPlaying ? "󰏤" : "󰐊"; active: true; onClicked: root.player.togglePlaying() }
                PanelButton { icon: "󰒭"; onClicked: root.player.next() }
                Item { Layout.fillWidth: true }
                Bars { count: 16; maxHeight: 22; tint: root.tint }
            }
        }
    }
}
