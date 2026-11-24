import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.components
import qs.services

Item {
    id: root

    CoverSource { id: coverSrc; row: root.head }

    property var head: null
    signal play(bool shuffle)
    signal queue

    implicitHeight: head ? 156 : 0
    visible: !!head

    RowLayout {
        anchors.fill: parent
        anchors.bottomMargin: 12
        spacing: Theme.sp7

        ClippingRectangle {
            Layout.preferredWidth: 140
            Layout.preferredHeight: 140
            radius: root.head && root.head.kind === "artist" ? 70 : Theme.rCard
            color: Theme.surface0
            Text {
                anchors.centerIn: parent
                visible: big.status !== Image.Ready
                text: root.head && root.head.kind === "artist" ? "󰠃" : "󰀥"
                color: Theme.overlay
                font.family: Theme.fontMono
                font.pixelSize: Theme.iconXl
            }
            Image {
                id: big
                anchors.fill: parent
                source: coverSrc.url
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 300
                visible: status === Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.sp3
            Text {
                text: !root.head ? "" : root.head.kind === "album" ? "Album" : root.head.kind === "artist" ? "Artist" : "Playlist"
                color: Theme.accent
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSm
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: root.head ? root.head.title : ""
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsHead
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: !root.head ? "" : [root.head.artist || "", root.head.year || "", root.head.count ? root.head.count + (root.head.kind === "artist" ? " albums" : " songs") : "", root.head.seconds ? Music.fmt(root.head.seconds) : "", root.head.source === "local" ? "on this machine" : (root.head.source || "")].filter(x => x).join(", ")
                elide: Text.ElideRight
                color: Theme.subtext
                font.family: Theme.fontUi
                font.features: ({ "tnum": 1 })
                font.pixelSize: Theme.fsMd
            }
            RowLayout {
                Layout.topMargin: Theme.sp4
                spacing: Theme.sp4
                PanelButton { icon: "󰐊"; label: root.head && root.head.kind === "artist" ? "Play all" : "Play"; active: true; activeFocusOnTab: false; onClicked: root.play(false) }
                PanelButton { visible: !!root.head && root.head.kind !== "artist"; icon: "󰐕"; label: "Queue"; activeFocusOnTab: false; onClicked: root.queue() }
            }
        }
    }
}
