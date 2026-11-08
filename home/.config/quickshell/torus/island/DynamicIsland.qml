import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    readonly property bool narrow: screen ? screen.width < 1400 : false
    readonly property bool focused: Store.focusedScreen === screen
    readonly property bool flashing: Island.state === "osd" || Island.state === "notification"
    readonly property string resting: Island.recording ? "recording" : (Focus.running ? "focus" : (narrow ? "" : (Island.player ? "media" : "idle")))
    readonly property string mode: flashing && focused ? Island.state : resting
    readonly property bool lyricRow: mode === "media" && Lyrics.line !== ""
    readonly property int pillWidth: {
        switch (mode) {
        case "osd": return 300
        case "notification": return 440
        case "recording": return 170
        case "focus": return 150
        case "media": return lyricRow ? 440 : 380
        case "idle": return Math.min(360, Math.max(170, idleText.implicitWidth + 64))
        default: return 0
        }
    }
    readonly property int pillHeight: mode === "notification" ? 56 : Store.barHeight

    onModeChanged: Island.report(screen.name, mode === "" ? "hidden" : mode)
    Component.onCompleted: Island.report(screen.name, mode === "" ? "hidden" : mode)

    anchors.top: true
    margins.top: narrow ? Store.barGap - 4 : (Store.barPreset === "compact" ? 3 : 4)
    implicitWidth: 480
    implicitHeight: 64
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: !Store.barHidden
    mask: Region { item: pill }
    WlrLayershell.namespace: "torus-island"
    WlrLayershell.layer: WlrLayer.Top

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: root.pillWidth
        height: root.pillHeight
        radius: Math.min(height / 2, 20)
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: root.mode === "recording" ? Qt.alpha(Theme.red, 0.7) : Qt.alpha(Theme.accent, 0.35)
        opacity: root.mode === "" ? 0 : 1
        clip: true
        Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (root.mode === "focus" && mouse.button === Qt.RightButton)
                    Focus.stop()
                else if (root.mode === "notification")
                    Store.setOpen("center", true)
                else if (root.mode === "recording")
                    Quickshell.execDetached(["torus-record", "toggle"])
                else if (root.mode === "media" && mouse.button === Qt.RightButton && Island.player)
                    Island.player.togglePlaying()
                else
                    Store.toggle("dashboard")
            }
            onWheel: wheel => {
                if (root.mode === "media" && Island.player)
                    wheel.angleDelta.y > 0 ? Island.player.next() : Island.player.previous()
            }
        }

        RowLayout {
            visible: root.mode === "idle"
            anchors.centerIn: parent
            spacing: 8
            readonly property var win: Hyprland.activeToplevel
            readonly property string appId: win && win.wayland && win.wayland.appId ? win.wayland.appId : ""
            IconImage {
                implicitSize: 16
                visible: parent.appId !== ""
                source: {
                    const e = DesktopEntries.applications.values.length >= 0 ? DesktopEntries.heuristicLookup(parent.appId) : null
                    return Quickshell.iconPath(e ? e.icon : "", "application-x-executable")
                }
            }
            Text {
                id: idleText
                text: parent.win && parent.win.title ? parent.win.title : "marc @ os"
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
                Layout.maximumWidth: 280
            }
        }

        RowLayout {
            visible: root.mode === "media"
            anchors.fill: parent
            anchors.leftMargin: 5
            anchors.rightMargin: 14
            spacing: 8

            Item {
                Layout.preferredWidth: root.pillHeight - 6
                Layout.preferredHeight: root.pillHeight - 6

                ClippingRectangle {
                    id: disk
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.crust
                    border.width: 1
                    border.color: Qt.alpha(Theme.accent, 0.5)

                    Text {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        text: "󰎆"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                    }
                    Image {
                        id: art
                        anchors.fill: parent
                        anchors.margins: 1
                        source: Island.player ? Island.player.trackArtUrl : ""
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 5
                        height: 5
                        radius: 2.5
                        color: Theme.base
                        border.width: 1
                        border.color: Qt.alpha(Theme.text, 0.4)
                    }
                    RotationAnimation on rotation {
                        running: root.mode === "media"
                        paused: running && !(Island.player && Island.player.isPlaying)
                        from: 0
                        to: 360
                        duration: 6000
                        loops: Animation.Infinite
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1

                Text {
                    Layout.fillWidth: true
                    text: Island.player ? (Island.player.trackTitle + (Island.player.trackArtist ? "  ·  " + Island.player.trackArtist : "")) : ""
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: root.lyricRow ? Theme.fontSize - 1 : Theme.fontSize
                    font.weight: root.lyricRow ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
                Text {
                    id: lyric
                    Layout.fillWidth: true
                    visible: root.lyricRow
                    text: Lyrics.line
                    color: Theme.accent
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSize - 2
                    font.italic: true
                    elide: Text.ElideRight
                    Behavior on text {
                        SequentialAnimation {
                            NumberAnimation { target: lyric; property: "opacity"; to: 0; duration: 120 }
                            PropertyAction {}
                            NumberAnimation { target: lyric; property: "opacity"; to: 1; duration: 220 }
                        }
                    }
                }
            }

            Bars { count: 8; maxHeight: 14; barWidth: 3 }
        }

        RowLayout {
            visible: root.mode === "osd"
            anchors.centerIn: parent
            spacing: 10
            Text {
                text: Island.flashData.icon || ""
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSize + 3
            }
            Rectangle {
                visible: Island.flashData.value !== undefined && Island.flashData.value >= 0
                Layout.preferredWidth: 150
                Layout.preferredHeight: 6
                radius: 3
                color: Theme.surface1
                Rectangle {
                    width: parent.width * Math.min(1, Math.max(0, Island.flashData.value || 0))
                    height: parent.height
                    radius: 3
                    color: (Island.flashData.value || 0) > 1 ? Theme.peach : Theme.accent
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }
            Text {
                text: Island.flashData.label || ""
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSize
            }
        }

        RowLayout {
            visible: root.mode === "notification"
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 16
            spacing: 10
            NotifIcon {
                size: 28
                image: Island.flashData.image || ""
                appIcon: Island.flashData.icon || ""
                app: Island.flashData.app || ""
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: Island.flashData.summary || ""
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSize + 1
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: Island.flashData.body || Island.flashData.app || ""
                    color: Theme.subtext
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSize - 1
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }
        }

        RowLayout {
            visible: root.mode === "focus"
            anchors.centerIn: parent
            spacing: 8
            Canvas {
                id: ring
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                property real p: Focus.progress
                onPChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d")
                    c.reset()
                    c.lineWidth = 2.5
                    c.strokeStyle = Theme.surface1
                    c.beginPath(); c.arc(8, 8, 6, 0, 2 * Math.PI); c.stroke()
                    c.strokeStyle = Theme.accent
                    c.beginPath(); c.arc(8, 8, 6, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * (1 - p)); c.stroke()
                }
            }
            Text {
                text: "Focus " + String(Math.floor(Focus.left / 60)).padStart(2, "0") + ":" + String(Focus.left % 60).padStart(2, "0")
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSize
            }
        }

        RowLayout {
            visible: root.mode === "recording"
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                radius: 5
                color: Theme.red
                SequentialAnimation on opacity {
                    running: root.mode === "recording"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 700 }
                    NumberAnimation { to: 1; duration: 700 }
                }
            }
            Text {
                id: recText
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSize
                text: "REC 00:00"
                Timer {
                    interval: 500
                    repeat: true
                    running: root.mode === "recording"
                    triggeredOnStart: true
                    onTriggered: {
                        const s = Math.max(0, Math.floor((Date.now() - Island.recordStart) / 1000))
                        recText.text = "REC " + String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                    }
                }
            }
        }
    }
}
