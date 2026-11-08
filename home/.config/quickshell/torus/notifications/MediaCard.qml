import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.components

Rectangle {
    id: root

    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    visible: player !== null
    implicitHeight: 96
    radius: Theme.radius
    color: Theme.surface0

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 72
            Layout.preferredHeight: 72
            radius: 8
            color: Theme.mantle
            clip: true
            Image {
                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                visible: !root.player || !root.player.trackArtUrl
                text: "󰎆"
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: 28
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: root.player ? root.player.trackTitle : ""
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: 14
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
            Row {
                spacing: 6
                PanelButton { icon: "󰒮"; onClicked: root.player.previous() }
                PanelButton { icon: root.player && root.player.isPlaying ? "󰏤" : "󰐊"; active: true; onClicked: root.player.togglePlaying() }
                PanelButton { icon: "󰒭"; onClicked: root.player.next() }
            }
        }
    }
}
