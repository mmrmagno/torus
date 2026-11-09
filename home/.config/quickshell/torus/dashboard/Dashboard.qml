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

    screen: Store.screenFor("dashboard")
    visible: Store.isOpen("dashboard") || motion.leaving
    anchors.top: true
    margins.top: Store.barGap
    implicitWidth: Math.min(900, (screen ? screen.width : 900) - 40)
    implicitHeight: Math.min(content.implicitHeight + 32, (screen ? screen.height : 1000) - Store.barGap - 16)
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
            id: motion
            target: parent
            shown: Store.isOpen("dashboard") && !Store.moving
        }
        anchors.fill: parent
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glass)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        focus: true
        Keys.onEscapePressed: Store.setOpen("dashboard", false)

        Flickable {
            anchors.fill: parent
            anchors.margins: 16
            contentHeight: content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

        GridLayout {
            readonly property int calRow: Math.max(250, cal.implicitHeight + 28)
            id: content
            width: parent.width
            columns: root.implicitWidth < 700 ? 1 : 3
            columnSpacing: Theme.sp6
            rowSpacing: Theme.sp6

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.sp1
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "hh:mm")
                        color: Theme.accent
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsDisplay
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                        color: Theme.subtext
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsLg
                    }
                    Text {
                        readonly property var next: Agenda.events.find(e => !e.allDay && e.at.getTime() > clock.date.getTime() && e.start.slice(0, 10) === Qt.formatDate(clock.date, "yyyy-MM-dd"))
                        visible: next !== undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, 240)
                        elide: Text.ElideRight
                        text: next ? "next  " + next.start.slice(11) + "  " + next.title : ""
                        color: Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSm
                    }
                }
            }

            Card {
                title: Weather.place || "weather"
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                Column {
                    anchors.fill: parent
                    spacing: Theme.sp3
                    Row {
                        spacing: Theme.sp6
                        Text { text: Weather.icon; color: Theme.yellow; font.family: Theme.fontMono; font.pixelSize: 40 }
                        Column {
                            Text { text: Weather.temp; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsHead; font.weight: Font.DemiBold }
                            Text { text: Weather.ok ? Weather.desc + ", feels " + Weather.feels : Weather.desc; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
                        }
                    }
                    Row {
                        spacing: 14
                        visible: Weather.ok
                        Repeater {
                            model: Weather.hours
                            Column {
                                required property var modelData
                                Text { text: modelData.t; color: Theme.overlay; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs }
                                Text { text: modelData.icon + " " + modelData.temp; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsSm }
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
                    spacing: Theme.sp2
                    StatRow { label: "cpu"; value: Math.round(SysStats.cpu) + "%" + (SysStats.cpuTemp >= 0 ? "  " + SysStats.cpuTemp + "°" : ""); hist: SysStats.cpuHist; tint: Theme.accent }
                    StatRow { label: "gpu"; value: (SysStats.gpuBusy >= 0 ? SysStats.gpuBusy + "%" : "--") + (SysStats.gpuTemp >= 0 ? "  " + SysStats.gpuTemp + "°" : ""); hist: SysStats.gpuHist; tint: Theme.sapphire }
                    StatRow { label: "memory"; value: SysStats.memUsed.toFixed(1) + " / " + SysStats.memTotal.toFixed(0) + " G"; hist: SysStats.memHist; tint: Theme.green }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: content.calRow
                Calendar { id: cal; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top }
            }

            Card {
                title: "quick settings"
                Layout.fillWidth: true
                Layout.preferredHeight: content.calRow
                Column {
                    anchors.fill: parent
                    spacing: Theme.sp5
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
                        spacing: Theme.sp3
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
                        PanelButton { icon: "󰑓"; label: Session.on ? "Session: on" : "Session: off"; active: Session.on; onClicked: { Store.setOpen("dashboard", false); Store.setOpen("session", true) } }
                        PanelButton { icon: "󰓅"; label: "Power"; onClicked: Quickshell.execDetached(["sh", "-c", "p=$(powerprofilesctl get); case $p in performance) n=balanced;; balanced) n=power-saver;; *) n=performance;; esac; powerprofilesctl set $n; notify-send -a torus \"Power profile\" $n"]) }
                        PanelButton { icon: "󰏘"; label: "Theme"; onClicked: { Store.setOpen("dashboard", false); Store.setOpen("theme", true) } }
                        PanelButton { icon: "󰖲"; label: "Widgets: " + Store.widgets; active: Store.widgets !== "off"; onClicked: Store.setWidgets("next") }
                    }
                }
            }

            Card {
                title: "network"
                Layout.fillWidth: true
                Layout.preferredHeight: content.calRow
                Column {
                    anchors.fill: parent
                    spacing: Theme.sp3
                    Row {
                        spacing: Theme.sp6
                        Text { text: "󰇚 " + SysStats.rate(SysStats.rxRate); color: Theme.sapphire; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd }
                        Text { text: "󰕒 " + SysStats.rate(SysStats.txRate); color: Theme.peach; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd }
                    }
                    Item {
                        width: parent.width
                        height: 44
                        Spark { anchors.fill: parent; values: SysStats.rxHist; auto: true; tint: Theme.sapphire }
                        Spark { anchors.fill: parent; values: SysStats.txHist; auto: true; tint: Theme.peach }
                    }
                    Rectangle { width: parent.width; height: 1; color: Qt.alpha(Theme.surface1, 0.6) }
                    Repeater {
                        model: About.rows.filter(r => ["os", "kernel", "uptime", "packages", "wm"].indexOf(r.k) >= 0)
                        Row {
                            required property var modelData
                            spacing: Theme.sp4
                            Text { text: modelData.k; width: 64; color: Theme.mauve; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs }
                            Text { text: modelData.v; width: 150; elide: Text.ElideRight; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs }
                        }
                    }
                }
            }

            MediaCard {
                Layout.fillWidth: true
                Layout.columnSpan: content.columns
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
                    spacing: Theme.sp5
                    Repeater {
                        model: Object.keys(Displays.levels).sort()
                        Row {
                            id: displayRow
                            required property string modelData
                            readonly property real level: Displays.levels[modelData] || 0
                            width: displayRows.width
                            spacing: Theme.sp5
                            Text { text: "󰍹"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.icon; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: displayRow.modelData; width: 60; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd; anchors.verticalCenter: parent.verticalCenter }
                            Item {
                                width: displayRow.width - 140
                                height: 18
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    id: dTrack
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 6
                                    radius: Theme.rXs
                                    color: Theme.surface1
                                    Rectangle { width: parent.width * displayRow.level / 100; height: parent.height; radius: Theme.rXs; color: Theme.yellow }
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
                            Text { text: Math.round(displayRow.level) + "%"; width: 40; horizontalAlignment: Text.AlignRight; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: Theme.fsSm; anchors.verticalCenter: parent.verticalCenter }
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
                title: Island.recording ? "Recordings · recording now" : "Recordings"
                visible: Recordings.count > 0 || Island.recording
                Layout.fillWidth: true
                Layout.columnSpan: content.columns
                Layout.preferredHeight: 92
                Row {
                    anchors.fill: parent
                    spacing: Theme.sp4
                    Text {
                        visible: Recordings.count === 0
                        text: "No recordings yet. SUPER+SHIFT+R starts one, SUPER+ALT+R keeps a replay buffer."
                        color: Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSm
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
                    PanelButton {
                        icon: "󰄀"
                        label: "Studio"
                        onClicked: { Store.setOpen("dashboard", false); Store.setOpen("capture", true) }
                    }
                }
            }
        }
        }
    }

    component StatRow: Item {
        property string label
        property string value
        property var hist: []
        property color tint: Theme.accent
        width: parent ? parent.width : 200
        height: 34
        Text { text: parent.label; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
        Text { anchors.right: parent.right; text: parent.value; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsSm }
        Spark { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 18; values: parent.hist; tint: parent.tint }
    }
}
