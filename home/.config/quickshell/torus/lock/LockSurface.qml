import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs
import qs.background
import qs.services

Item {
    id: root

    required property var lock
    required property var screen
    readonly property real side: Math.min(width, height)

    focus: true
    property bool entered: false
    opacity: lock.fading || !entered ? 0 : 1
    scale: lock.fading ? 1.04 : (entered ? 1 : 0.97)
    Behavior on opacity { NumberAnimation { duration: lock.fading ? 180 : 260; easing.type: lock.fading ? Easing.InCubic : Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: lock.fading ? 200 : 320; easing.type: lock.fading ? Easing.InCubic : Easing.OutCubic } }
    Component.onCompleted: {
        entered = true
        console.info("lock: surface shown, theme colors " + (Theme.c.crust ? "loaded" : "not loaded, using the fallback"))
        forceActiveFocus()
        Island.readCaps()
    }
    TapHandler { onTapped: root.forceActiveFocus() }
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isLaptopBattery
    readonly property var nextEvent: Agenda.events.find(e => !e.allDay && e.at.getTime() > clock.date.getTime() && e.start.slice(0, 10) === Qt.formatDate(clock.date, "yyyy-MM-dd"))
    readonly property var appCounts: {
        const c = {}
        for (const n of Notifs.list)
            c[n.appName || "other"] = (c[n.appName || "other"] || 0) + 1
        return Object.keys(c).sort((a, b) => c[b] - c[a]).slice(0, 4).map(a => a + (c[a] > 1 ? " " + c[a] : ""))
    }

    Keys.onPressed: event => {
        lock.poke()
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            lock.submit()
        else if (event.key === Qt.Key_Backspace)
            lock.buffer = (event.modifiers & Qt.ControlModifier) ? "" : lock.buffer.slice(0, -1)
        else if (event.key === Qt.Key_Escape)
            lock.buffer = ""
        else if (event.text !== "")
            lock.buffer += event.text
        event.accepted = true
    }

    Image {
        id: shot
        anchors.fill: parent
        visible: false
        cache: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        source: root.screen && Store.locked ? "file://" + root.lock.dir + "/" + root.screen.name + ".png" : ""
    }

    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.status === Image.Ready
        blurEnabled: true
        blur: 1
        blurMax: 64
        brightness: -0.18
        saturation: -0.2
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.crust, shot.status === Image.Ready ? 0.45 : 1) }
            GradientStop { position: 1; color: Qt.alpha(Theme.base, shot.status === Image.Ready ? 0.7 : 1) }
        }
    }

    readonly property var lockPlayer: Island.player || (Mpris.players.values.length > 0 ? Mpris.players.values[0] : null)

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 14

        DonutView {
            id: lockDonut
            Layout.alignment: Qt.AlignHCenter
            property real float: 0
            transform: Translate { y: 6 * Math.sin(lockDonut.float) }
            NumberAnimation on float { running: Store.locked && root.lock.awake && Theme.motion > 0; from: 0; to: 2 * Math.PI; duration: 7000; loops: Animation.Infinite }
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            live: Store.locked && root.lock.awake
            shape: Store.wallFor(root.screen ? root.screen.name : "") === "xwing" ? "xwing" : "torus"
            cellH: Math.max(4, Math.round(root.side * 0.3 / (Store.wallFor(root.screen ? root.screen.name : "") === "xwing" ? DonutClock.h * 2 : DonutClock.h)))
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.sp3
            Text {
                id: bigClock
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Math.round(root.side * 0.09)
                font.weight: Font.Bold
            }
            Text {
                id: secs
                anchors.baseline: bigClock.baseline
                text: Qt.formatDateTime(clock.date, "ss")
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Math.round(root.side * 0.025)
                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: secs; property: "opacity"; to: 0.35; duration: 120 }
                        PropertyAction {}
                        NumberAnimation { target: secs; property: "opacity"; to: 1; duration: 260 }
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            color: Theme.subtext
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsXl
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            Row {
                spacing: Theme.sp3
                visible: Weather.ok
                Text { text: Weather.icon; color: Theme.yellow; font.family: Theme.fontMono; font.pixelSize: Theme.icon; anchors.verticalCenter: parent.verticalCenter }
                Text { text: Weather.temp; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsBase; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: Theme.sp3
                visible: root.nextEvent !== undefined
                Text { text: "󰃭"; color: Theme.sapphire; font.family: Theme.fontMono; font.pixelSize: Theme.icon; anchors.verticalCenter: parent.verticalCenter }
                Text { text: root.nextEvent ? root.nextEvent.start.slice(11) + "  " + root.nextEvent.title : ""; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsBase; anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, 260); elide: Text.ElideRight }
            }
            Row {
                spacing: Theme.sp3
                visible: root.hasBattery
                Text { text: root.hasBattery && root.battery.state === UPowerDeviceState.Charging ? "󰂄" : "󰁹"; color: root.hasBattery && root.battery.percentage < 0.2 ? Theme.red : Theme.green; font.family: Theme.fontMono; font.pixelSize: Theme.icon; anchors.verticalCenter: parent.verticalCenter }
                Text { text: root.hasBattery ? Math.round(root.battery.percentage * 100) + "%" + (root.battery.state === UPowerDeviceState.Charging ? " charging" : "") : ""; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsBase; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.sp3
            visible: root.appCounts.length > 0
            Text { text: "󰂚"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.icon; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: root.appCounts
                Rectangle {
                    required property string modelData
                    width: appText.implicitWidth + 16
                    height: 22
                    radius: 11
                    color: Qt.alpha(Theme.surface0, 0.7)
                    Text { id: appText; anchors.centerIn: parent; text: parent.modelData; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                }
            }
        }

        Rectangle {
            id: field
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            Layout.preferredWidth: 320
            Layout.preferredHeight: 44
            radius: 22
            color: Qt.alpha(Theme.base, Theme.glassCard)
            border.width: 2
            border.color: root.lock.message !== "" ? Theme.red : (Island.caps ? Theme.peach : (root.lock.busy ? Theme.accent : Qt.alpha(Theme.accent, 0.6)))
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -6
                radius: parent.radius + 6
                color: "transparent"
                border.width: 4
                border.color: Qt.alpha(Theme.accent, 0.5)
                opacity: 0
                SequentialAnimation on opacity {
                    running: root.lock.busy
                    loops: Animation.Infinite
                    NumberAnimation { to: 1; duration: 420; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.15; duration: 420; easing.type: Easing.InOutSine }
                    onStopped: parent.opacity = 0
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: Theme.sp3
                visible: root.lock.buffer.length > 0
                Repeater {
                    model: Math.min(root.lock.buffer.length, 24)
                    Rectangle {
                        width: 9
                        height: 9
                        radius: 5
                        color: Theme.accent
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.lock.buffer.length === 0
                text: root.lock.busy ? "checking" : (Island.caps ? "password  ·  caps lock on" : "password")
                color: Theme.overlay
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsLg
            }

            transform: Translate { id: nudge }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: nudge; property: "x"; to: 18; duration: 50 }
                NumberAnimation { target: nudge; property: "x"; to: -18; duration: 80 }
                NumberAnimation { target: nudge; property: "x"; to: 9; duration: 70 }
                NumberAnimation { target: nudge; property: "x"; to: 0; duration: 60 }
            }

            Connections {
                target: root.lock
                function onFailsChanged() {
                    if (root.lock.fails > 0)
                        shake.restart()
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 18
            text: root.lock.message !== "" ? root.lock.message + (Island.caps ? "  ·  Caps Lock is on" : "") : (Island.caps ? "󰪛  Caps Lock is on" : "")
            color: root.lock.message !== "" ? Theme.red : Theme.peach
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBase
        }
    
        Rectangle {
            id: nowPlaying
            readonly property var player: root.lockPlayer
            visible: player !== null
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            Layout.preferredWidth: Math.min(420, root.width - 48)
            Layout.preferredHeight: 76
            radius: Theme.rPanel
            color: Qt.alpha(Theme.base, Theme.glassCard)
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.3)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: Theme.sp6
                ClippingRectangle {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    radius: Theme.radius
                    color: Theme.surface0
                    Image {
                        anchors.fill: parent
                        source: nowPlaying.player ? nowPlaying.player.trackArtUrl : ""
                        sourceSize.width: 112
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp1
                    Text { Layout.fillWidth: true; text: nowPlaying.player ? nowPlaying.player.trackTitle : ""; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsLg; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; text: nowPlaying.player ? nowPlaying.player.trackArtist : ""; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd; elide: Text.ElideRight }
                }
                Repeater {
                    model: [["󰒮", "previous"], ["play", "togglePlaying"], ["󰒭", "next"]]
                    Rectangle {
                        id: mediaBtn
                        required property var modelData
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 17
                        color: mediaHover.hovered ? Theme.accent : Theme.surface0
                        Text {
                            anchors.centerIn: parent
                            text: mediaBtn.modelData[0] === "play" ? (nowPlaying.player && nowPlaying.player.isPlaying ? "󰏤" : "󰐊") : mediaBtn.modelData[0]
                            color: mediaHover.hovered ? Theme.crust : Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.icon
                        }
                        HoverHandler { id: mediaHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: if (nowPlaying.player) nowPlaying.player[mediaBtn.modelData[1]]() }
                    }
                }
            }
        }
}

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 32
        spacing: 18
        Text {
            visible: Island.caps
            text: "󰪛 CAPS"
            color: Theme.peach
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsLg
        }
        Text {
            visible: root.lock.layout !== ""
            text: "󰌌 " + root.lock.layout
            color: Theme.subtext
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsLg
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

}
