import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services
import qs.notifications

PanelWindow {
    id: root

    screen: Store.focusedScreen
    visible: Store.isOpen("dashboard")
    anchors.top: true
    margins.top: Store.barGap
    implicitWidth: Math.min(900, (screen ? screen.width : 900) - 40)
    implicitHeight: content.implicitHeight + 32
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onVisibleChanged: if (visible) {
        if (!Weather.ok)
            Weather.refresh()
        Displays.refresh()
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    Rectangle {
        PanelMotion {
            target: parent
            shown: root.visible
        }
        anchors.fill: parent
        radius: 18
        color: Qt.alpha(Theme.base, Theme.glass)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        focus: true
        Keys.onEscapePressed: Store.setOpen("dashboard", false)

        GridLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 16
            columns: root.implicitWidth < 700 ? 1 : 3
            columnSpacing: 12
            rowSpacing: 12

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "hh:mm")
                        color: Theme.accent
                        font.family: Theme.fontUi
                        font.pixelSize: 56
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                        color: Theme.subtext
                        font.family: Theme.fontUi
                        font.pixelSize: 14
                    }
                }
            }

            Card {
                title: Weather.place || "weather"
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                Column {
                    anchors.fill: parent
                    spacing: 6
                    Row {
                        spacing: 12
                        Text { text: Weather.icon; color: Theme.yellow; font.family: Theme.fontMono; font.pixelSize: 40 }
                        Column {
                            Text { text: Weather.temp; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: 26; font.weight: Font.DemiBold }
                            Text { text: Weather.ok ? Weather.desc + ", feels " + Weather.feels : Weather.desc; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: 12 }
                        }
                    }
                    Row {
                        spacing: 14
                        visible: Weather.ok
                        Repeater {
                            model: Weather.hours
                            Column {
                                required property var modelData
                                Text { text: modelData.t; color: Theme.overlay; font.family: Theme.fontMono; font.pixelSize: 10 }
                                Text { text: modelData.icon + " " + modelData.temp; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: 11 }
                            }
                        }
                    }
                }
            }

            Card {
                title: "system"
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                Column {
                    anchors.fill: parent
                    spacing: 8
                    Meter { label: "cpu"; value: Math.round(SysStats.cpu) + "%" + (SysStats.cpuTemp >= 0 ? "  " + SysStats.cpuTemp + "°" : ""); fraction: SysStats.cpu / 100 }
                    Meter { label: "gpu"; value: (SysStats.gpuBusy >= 0 ? SysStats.gpuBusy + "%" : "--") + (SysStats.gpuTemp >= 0 ? "  " + SysStats.gpuTemp + "°" : ""); fraction: Math.max(0, SysStats.gpuBusy) / 100; tint: Theme.sapphire }
                    Meter { label: "memory"; value: SysStats.memUsed.toFixed(1) + " / " + SysStats.memTotal.toFixed(0) + " G"; fraction: SysStats.memPercent / 100; tint: Theme.green }
                }
            }

            Card {
                title: "displays"
                visible: Displays.available
                Layout.fillWidth: true
                Layout.columnSpan: content.columns
                Layout.preferredHeight: displayRows.implicitHeight + 44
                Column {
                    id: displayRows
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 10
                    Repeater {
                        model: Object.keys(Displays.levels).sort()
                        Row {
                            id: displayRow
                            required property string modelData
                            readonly property real level: Displays.levels[modelData] || 0
                            width: displayRows.width
                            spacing: 10
                            Text { text: "󰍹"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: displayRow.modelData; width: 60; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            Item {
                                width: displayRow.width - 140
                                height: 18
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    id: dTrack
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 6
                                    radius: 3
                                    color: Theme.surface1
                                    Rectangle { width: parent.width * displayRow.level / 100; height: parent.height; radius: 3; color: Theme.yellow }
                                }
                                Rectangle {
                                    x: Math.max(0, Math.min(dTrack.width - width, dTrack.width * displayRow.level / 100 - width / 2))
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14; height: 14; radius: 7
                                    color: Theme.text
                                    border.width: 2
                                    border.color: Theme.yellow
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    function pick(x) { Displays.set(displayRow.modelData, Math.max(0, Math.min(100, x / dTrack.width * 100))) }
                                    onPressed: mouse => pick(mouse.x)
                                    onPositionChanged: mouse => { if (pressed) pick(mouse.x) }
                                    onWheel: wheel => Displays.set(displayRow.modelData, Math.max(0, Math.min(100, displayRow.level + (wheel.angleDelta.y > 0 ? 5 : -5))))
                                }
                            }
                            Text { text: Math.round(displayRow.level) + "%"; width: 40; horizontalAlignment: Text.AlignRight; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            Card {
                title: "sound"
                Layout.fillWidth: true
                Layout.columnSpan: content.columns
                Layout.preferredHeight: mixer.implicitHeight + 44
                Mixer {
                    id: mixer
                    anchors.left: parent.left
                    anchors.right: parent.right
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(250, cal.implicitHeight + 28)
                Calendar { id: cal; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top }
            }

            Card {
                title: "quick settings"
                Layout.fillWidth: true
                Layout.preferredHeight: 250
                Column {
                    anchors.fill: parent
                    spacing: 10
                    Item {
                        width: parent.width
                        height: volMeter.implicitHeight
                        readonly property var a: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
                        Meter {
                            id: volMeter
                            width: parent.width
                            label: "volume"
                            value: parent.a ? Math.round(parent.a.volume * 100) + "%" : "--"
                            fraction: parent.a ? parent.a.volume : 0
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: mouse => { if (parent.a) parent.a.volume = mouse.x / width }
                            onWheel: wheel => { if (parent.a) parent.a.volume = Math.max(0, Math.min(1.5, parent.a.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))) }
                        }
                    }
                    Flow {
                        width: parent.width
                        spacing: 6
                        PanelButton {
                            readonly property var a: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio
                            icon: a && a.muted ? "󰍭" : "󰍬"
                            label: "Mic"
                            active: a ? !a.muted : false
                            onClicked: if (a) a.muted = !a.muted
                        }
                        PanelButton { icon: "󰂛"; label: "DND"; active: Store.dnd; onClicked: Store.dnd = !Store.dnd }
                        PanelButton { icon: "󰊴"; label: "Game"; active: Store.gamemode; onClicked: Quickshell.execDetached(["torus-gamemode"]) }
                        PanelButton { icon: "󰖔"; label: "Night"; active: NightLight.on; onClicked: NightLight.toggle() }
                        PanelButton { icon: "󰓅"; label: "Power"; onClicked: Quickshell.execDetached(["sh", "-c", "p=$(powerprofilesctl get); case $p in performance) n=balanced;; balanced) n=power-saver;; *) n=performance;; esac; powerprofilesctl set $n; notify-send -a torus \"Power profile\" $n"]) }
                        PanelButton { icon: "󰏘"; label: "Accent"; onClicked: Quickshell.execDetached(["torus-menu", "accent"]) }
                        PanelButton { icon: "󰸉"; label: "Wallpaper"; onClicked: Quickshell.execDetached(["torus-menu", "wallpaper"]) }
                        PanelButton { icon: "󰖲"; label: "Widgets: " + Store.widgets; active: Store.widgets !== "off"; onClicked: Store.setWidgets("next") }
                    }
                }
            }

            Card {
                title: "marc @ os"
                Layout.fillWidth: true
                Layout.preferredHeight: 250
                Column {
                    anchors.fill: parent
                    spacing: 3
                    Repeater {
                        model: About.rows
                        Row {
                            required property var modelData
                            spacing: 8
                            Text { text: modelData.k; width: 64; color: Theme.mauve; font.family: Theme.fontMono; font.pixelSize: 11 }
                            Text { text: modelData.v; width: 180; elide: Text.ElideRight; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: 11 }
                        }
                    }
                }
            }

            MediaCard {
                Layout.fillWidth: true
                Layout.columnSpan: content.columns
            }

            Card {
                title: Island.recording ? "Recordings · recording now" : "Recordings"
                Layout.fillWidth: true
                Layout.columnSpan: content.columns
                Layout.preferredHeight: 92
                Row {
                    anchors.fill: parent
                    spacing: 8
                    Text {
                        visible: Recordings.count === 0
                        text: "No recordings yet. SUPER+SHIFT+R starts one, SUPER+ALT+R keeps a replay buffer."
                        color: Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: 11
                    }
                    Repeater {
                        model: Recordings.latest
                        PanelButton {
                            required property var modelData
                            icon: "󰕧"
                            label: Qt.formatDateTime(modelData.date, "dd.MM hh:mm") + "  " + Math.round(modelData.size / 1048576) + " MB"
                            onClicked: Quickshell.execDetached(["xdg-open", modelData.path])
                        }
                    }
                    PanelButton {
                        visible: Recordings.count > 0
                        icon: "󰉋"
                        label: "Folder"
                        onClicked: Quickshell.execDetached(["xdg-open", Recordings.dir])
                    }
                }
            }
        }
    }
}
