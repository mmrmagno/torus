import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs
import qs.background
import qs.services

Item {
    id: root

    required property var lock
    required property var screen
    readonly property real side: Math.min(width, height)

    focus: true
    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: event => {
        lock.poke()
        if (lock.busy) {
            event.accepted = true
            return
        }
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
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            live: Store.locked && root.lock.awake
            shape: Store.wallpaper === "xwing" ? "xwing" : "torus"
            cellH: Math.max(4, Math.round(root.side * 0.3 / (Store.wallpaper === "xwing" ? DonutClock.h * 2 : DonutClock.h)))
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Math.round(root.side * 0.09)
            font.weight: Font.Bold
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            color: Theme.subtext
            font.family: Theme.fontUi
            font.pixelSize: 16
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            Row {
                spacing: 6
                visible: Weather.ok
                Text { text: Weather.icon; color: Theme.yellow; font.family: Theme.fontMono; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                Text { text: Weather.temp; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: 6
                visible: Store.notifCount > 0
                Text { text: "󰂚"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                Text { text: Store.notifCount + (Store.notifCount === 1 ? " notification" : " notifications"); color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
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
            border.color: root.lock.message !== "" ? Theme.red : (root.lock.busy ? Theme.peach : Qt.alpha(Theme.accent, 0.6))
            Behavior on border.color { ColorAnimation { duration: 160 } }

            Row {
                anchors.centerIn: parent
                spacing: 6
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
                text: root.lock.busy ? "checking" : "password"
                color: Theme.overlay
                font.family: Theme.fontUi
                font.pixelSize: 14
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
            text: root.lock.message
            color: Theme.red
            font.family: Theme.fontUi
            font.pixelSize: 13
        }
    
        Rectangle {
            id: nowPlaying
            readonly property var player: root.lockPlayer
            visible: player !== null
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            Layout.preferredWidth: Math.min(420, root.width - 48)
            Layout.preferredHeight: 76
            radius: 18
            color: Qt.alpha(Theme.base, Theme.glassCard)
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.3)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12
                ClippingRectangle {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    radius: 10
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
                    spacing: 2
                    Text { Layout.fillWidth: true; text: nowPlaying.player ? nowPlaying.player.trackTitle : ""; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; text: nowPlaying.player ? nowPlaying.player.trackArtist : ""; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: 12; elide: Text.ElideRight }
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
                            font.pixelSize: 15
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
            visible: Store.notifCount > 0
            text: "󰂚 " + Store.notifCount
            color: Theme.subtext
            font.family: Theme.fontMono
            font.pixelSize: 14
        }
        Text {
            visible: root.lock.layout !== ""
            text: "󰌌 " + root.lock.layout
            color: Theme.subtext
            font.family: Theme.fontMono
            font.pixelSize: 14
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

}
