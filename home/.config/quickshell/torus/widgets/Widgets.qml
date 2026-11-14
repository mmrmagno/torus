import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    readonly property bool portrait: screen ? screen.height > screen.width : false
    readonly property bool on: Store.widgets === "all" || (Store.widgets === "landscape" && !portrait)

    visible: on && !Store.widgetsQuiet
    onOnChanged: Store.reportWidgets(screen.name, on)
    Component.onCompleted: Store.reportWidgets(screen.name, on)

    anchors {
        left: true
        top: true
        bottom: true
    }
    implicitWidth: 380
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: media }
    WlrLayershell.namespace: "torus-widgets"
    WlrLayershell.layer: WlrLayer.Bottom

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.leftMargin: 56
        anchors.verticalCenter: parent.verticalCenter
        width: 300
        spacing: Theme.sp7

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: clockCol.implicitHeight
            Column {
                id: clockCol
                spacing: 0
                Text {
                    text: Qt.formatDateTime(clock.date, "hh:mm")
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 84
                    font.weight: Font.Bold
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    color: Theme.accent
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsTitle
                }
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                shadowBlur: 0.8
                shadowOpacity: 0.9
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: stats.implicitHeight + 28
            radius: 16
            color: Qt.alpha(Theme.base, Theme.glassCard)
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.25)
            Column {
                id: stats
                anchors.fill: parent
                anchors.margins: 14
                spacing: Theme.sp5
                Meter { label: "CPU"; value: Math.round(SysStats.cpu) + "%" + (SysStats.cpuTemp >= 0 ? "  " + SysStats.cpuTemp + "°C" : ""); fraction: SysStats.cpu / 100 }
                Meter { label: "Memory"; value: SysStats.memUsed.toFixed(1) + " / " + SysStats.memTotal.toFixed(0) + " GiB"; fraction: SysStats.memPercent / 100; tint: Theme.lavender }
                Meter { visible: SysStats.gpuBusy >= 0; label: "GPU"; value: SysStats.gpuBusy + "%" + (SysStats.gpuTemp >= 0 ? "  " + SysStats.gpuTemp + "°C" : ""); fraction: SysStats.gpuBusy / 100; tint: Theme.sapphire }
            }
        }

        Rectangle {
            id: media
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            visible: Island.player !== null
            radius: 16
            color: Qt.alpha(Theme.base, Theme.glassCard)
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.25)
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: Theme.sp6
                ClippingRectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    radius: Theme.radius
                    color: Theme.surface0
                    Text {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        text: "󰎆"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 22
                    }
                    Image {
                        id: art
                        anchors.fill: parent
                        source: Island.player ? Island.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp1
                    Text {
                        Layout.fillWidth: true
                        text: Island.player ? Island.player.trackTitle : ""
                        color: Theme.text
                        elide: Text.ElideRight
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsLg
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Island.player ? Island.player.trackArtist : ""
                        color: Theme.subtext
                        elide: Text.ElideRight
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsMd
                    }
                    Row {
                        spacing: 14
                        Repeater {
                            model: [["󰒮", "previous"], [Island.player && Island.player.isPlaying ? "󰏤" : "󰐊", "togglePlaying"], ["󰒭", "next"]]
                            Text {
                                required property var modelData
                                text: modelData[0]
                                color: hover.hovered ? Theme.lavender : Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsXl
                                HoverHandler { id: hover }
                                TapHandler { onTapped: if (Island.player) Island.player[parent.modelData[1]]() }
                            }
                        }
                    }
                }
                Bars { count: 6; maxHeight: 22; barWidth: 3 }
            }
        }
    }
}
