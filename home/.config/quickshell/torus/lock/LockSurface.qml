import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
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

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 14

        DonutView {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            live: Store.locked && root.lock.awake
            cellH: Math.max(6, Math.round(root.side * 0.3 / DonutClock.h))
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
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        visible: Island.player !== null
        width: Math.min(420, root.width - 48)
        height: 48
        radius: 24
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 12
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: Island.player ? Island.player.trackTitle + (Island.player.trackArtist ? "  ·  " + Island.player.trackArtist : "") : ""
                color: Theme.text
                elide: Text.ElideRight
                font.family: Theme.fontUi
                font.pixelSize: 13
            }
            Repeater {
                model: [["󰒮", "previous"], [Island.player && Island.player.isPlaying ? "󰏤" : "󰐊", "togglePlaying"], ["󰒭", "next"]]
                Text {
                    required property var modelData
                    text: modelData[0]
                    color: hover.hovered ? Theme.lavender : Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    HoverHandler { id: hover }
                    TapHandler { onTapped: if (Island.player) Island.player[parent.modelData[1]]() }
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
