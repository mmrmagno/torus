import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
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
    implicitHeight: Store.panelRoom(screen, 16)
    mask: Region { item: dashFrame }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("dashboard") && !Store.moving ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property var battery: ({})
    property string batteryError: ""

    onVisibleChanged: if (visible) {
        if (!Weather.ok)
            Weather.refresh()
        Displays.refresh()
        if (Island.hasBattery && !batteryProc.running)
            batteryProc.running = true
    }

    Process {
        id: batteryProc
        command: ["torus-battery", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.battery = JSON.parse(text)
                } catch (e) {
                    root.battery = {}
                }
            }
        }
    }

    Process {
        id: limitProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.battery = JSON.parse(text)
                    root.batteryError = ""
                } catch (e) {}
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") root.batteryError = text.trim().replace(/^torus-battery: /, "") }
    }

    HyprlandFocusGrab {
        active: Store.isOpen("dashboard") && root.backingWindowVisible
        windows: [root]
        onCleared: Store.setOpen("dashboard", false)
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    Rectangle {
        id: dashFrame
        Connections {
            target: root
            function onVisibleChanged() {
                if (root.visible)
                    dashFrame.forceActiveFocus()
            }
        }
        PanelMotion {
            id: motion
            target: dashFrame
            shown: Store.isOpen("dashboard") && !Store.moving
        }
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(content.implicitHeight + 32 + hintBar.height + Theme.sp5, root.implicitHeight)
        Behavior on height { enabled: root.visible; NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
        transformOrigin: Item.Top
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glass)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        focus: true
        Keys.onEscapePressed: Store.setOpen("dashboard", false)

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.margins: 11
            anchors.bottomMargin: 16 + hintBar.height + Theme.sp5
            contentHeight: content.implicitHeight + 10
            boundsBehavior: Flickable.StopAtBounds
            clip: true

        GridLayout {
            readonly property int calRow: Math.max(250, cal.implicitHeight + 28)
            id: content
            x: 5
            y: 5
            width: parent.width - 10
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
                status: Weather.ok ? "ready" : (Weather.busy || !Weather.tried ? "loading" : "error")
                statusText: status === "error" ? (Net.online ? "wttr.in is not answering" : "offline, weather waits for the network") : ""
                retryable: Net.online
                onRetry: Weather.refresh()
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
                        PanelButton {
                            readonly property var names: ["Power saver", "Balanced", "Performance"]
                            icon: PowerProfiles.profile === PowerProfile.Performance ? "󰓅" : (PowerProfiles.profile === PowerProfile.PowerSaver ? "󰾆" : "󰾅")
                            label: "Power: " + names[PowerProfiles.profile]
                            active: PowerProfiles.profile === PowerProfile.Performance
                            onClicked: Island.cyclePower()
                        }
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
                                    onReleased: Store.sound("tick")
                                    onWheel: wheel => {
                                        Displays.set(displayRow.modelData, Math.max(0, Math.min(100, displayRow.level + (wheel.angleDelta.y > 0 ? 5 : -5))))
                                        Store.sound("tick")
                                    }
                                }
                            }
                            Text { text: Math.round(displayRow.level) + "%"; width: 40; horizontalAlignment: Text.AlignRight; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: Theme.fsSm; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    Row {
                        spacing: Theme.sp3
                        PanelButton { visible: Object.keys(Displays.levels).length > 1; icon: "󰌹"; label: "Both together"; implicitHeight: 28; active: Displays.linked; onClicked: Displays.setLinked(!Displays.linked) }
                        PanelButton { icon: "󰖔"; label: "Dim with night light"; implicitHeight: 28; active: Displays.nightDim; onClicked: Displays.setNightDim(!Displays.nightDim) }
                    }
                }
            }

            Card {
                title: "battery"
                visible: Island.hasBattery
                Layout.fillWidth: true
                Layout.columnSpan: content.columns
                Layout.preferredHeight: 96
                status: root.battery.present === true ? "ready" : (batteryProc.running || root.battery.present === undefined ? "loading" : "empty")
                statusText: "no battery data"
                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.sp7
                    Column {
                        spacing: Theme.sp1
                        Text { text: root.battery.health >= 0 ? root.battery.health + "%" : "--"; color: root.battery.health >= 0 && root.battery.health < 70 ? Theme.peach : Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsHead; font.weight: Font.DemiBold }
                        Text { text: "health" + (root.battery.cycles > 0 ? "  ·  " + root.battery.cycles + " cycles" : ""); color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                    }
                    Item { Layout.fillWidth: true }
                    Column {
                        visible: root.battery.limit !== undefined && root.battery.limit !== "none"
                        spacing: Theme.sp2
                        Row {
                            spacing: Theme.sp4
                            anchors.right: parent.right
                            Text { text: "Stop charging at 80 %"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd; anchors.verticalCenter: parent.verticalCenter }
                            Toggle {
                                label: "charge limit"
                                checked: root.battery.on === true
                                onToggled: value => {
                                    limitProc.command = ["torus-battery", "limit", value ? "on" : "off"]
                                    limitProc.running = true
                                }
                            }
                        }
                        Text {
                            anchors.right: parent.right
                            text: root.batteryError !== "" ? root.batteryError : (root.battery.writable ? (root.battery.limit === "conservation" ? "the firmware's battery care mode" : "kinder to the battery when plugged in all day") : "needs sudo ./install.sh --system once")
                            color: root.batteryError !== "" ? Theme.peach : Theme.overlay
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSm
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
                status: Recordings.count === 0 && !Island.recording ? "empty" : "ready"
                statusText: "No recordings yet. SUPER+SHIFT+R starts one, SUPER+ALT+R keeps a replay buffer."
                Row {
                    anchors.fill: parent
                    spacing: Theme.sp4
                    Repeater {
                        model: Recordings.latest
                        PanelButton {
                            required property var modelData
                            icon: "󰕧"
                            label: Qt.formatDateTime(modelData.date, "dd.MM hh:mm") + "  " + Math.round(modelData.size / 1048576) + " MB"
                            onClicked: Quickshell.execDetached(["torus-launch", "xdg-open", modelData.path])
                        }
                    }
                    PanelButton {
                        visible: Recordings.count > 0
                        icon: "󰉋"
                        label: "Folder"
                        onClicked: Quickshell.execDetached(["torus-launch", "xdg-open", Recordings.dir])
                    }
                    PanelButton {
                        icon: "󰄀"
                        label: "Studio"
                        onClicked: { Store.setOpen("dashboard", false); Store.setOpen("capture", true) }
                    }
                }
            }

            CommuteCard {
                Layout.fillWidth: true
                Layout.columnSpan: content.columns
                Layout.preferredHeight: smoothHeight
            }
        }
        }

        ScrollFade { flick: scroller }

        KeyHints {
            id: hintBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16
            hints: [["Tab", "move"], ["↵", "press"], ["← / →", "slide"], ["Esc", "close"]]
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
