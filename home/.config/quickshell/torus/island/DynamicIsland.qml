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
    readonly property bool flashing: Island.state === "osd" || Island.state === "notification" || Island.state === "shot"
    readonly property string resting: Island.recording ? "recording" : (Timers.running ? "timer" : (Focus.running ? "focus" : (narrow ? "" : (Island.player ? "media" : "idle"))))
    readonly property string mode: flashing && focused ? Island.state : resting
    readonly property bool lyricRow: mode === "media" && Lyrics.line !== ""
    readonly property int pillWidth: {
        switch (mode) {
        case "osd": return 300
        case "notification": return 440
        case "shot": return 460
        case "recording": return 170
        case "focus": return 150
        case "timer": return Math.max(150, timerText.implicitWidth + 56)
        case "media": return lyricRow ? 440 : 380
        case "idle": return Math.min(360, Math.max(170, idleText.implicitWidth + 64))
        default: return 0
        }
    }
    readonly property int pillHeight: mode === "notification" ? 56 : (mode === "shot" ? 92 : Store.barHeight)

    onModeChanged: Island.report(screen.name, mode === "" ? "hidden" : mode)
    Component.onCompleted: Island.report(screen.name, mode === "" ? "hidden" : mode)

    anchors.top: true
    margins.top: narrow ? Store.barGap - 4 : (Store.barPreset === "compact" ? 3 : 4)
    implicitWidth: 480
    implicitHeight: 104
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
        Behavior on width { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on height { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        Behavior on opacity { NumberAnimation { duration: Theme.durMed } }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (root.mode === "focus" && mouse.button === Qt.RightButton)
                    Focus.stop()
                else if (root.mode === "timer")
                    mouse.button === Qt.RightButton ? Timers.stop() : Timers.togglePause()
                else if (root.mode === "notification")
                    Store.setOpen("center", true)
                else if (root.mode === "recording")
                    Quickshell.execDetached(["torus-record", "toggle"])
                else if (root.mode === "media" && mouse.button === Qt.RightButton && Island.player)
                    Island.player.togglePlaying()
                else
                    Store.toggleOn("dashboard", root.screen)
            }
            onWheel: wheel => {
                if (root.mode !== "media" || !Island.player)
                    return
                const sideways = wheel.angleDelta.x !== 0 || (wheel.modifiers & Qt.ShiftModifier)
                const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                if (sideways)
                    d > 0 ? Island.player.next() : Island.player.previous()
                else
                    Island.nudgePlayerVolume(d > 0 ? 0.05 : -0.05)
            }
        }

        RowLayout {
            visible: root.mode === "idle"
            anchors.centerIn: parent
            spacing: Theme.sp4
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
            spacing: Theme.sp4

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
                        font.pixelSize: Theme.fsMd
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
                        paused: running && !(Island.player && Island.player.isPlaying && root.focused)
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
                            NumberAnimation { target: lyric; property: "opacity"; to: 0; duration: Theme.durFast }
                            PropertyAction {}
                            NumberAnimation { target: lyric; property: "opacity"; to: 1; duration: Theme.durMed }
                        }
                    }
                }
            }

            Bars { count: 8; maxHeight: 14; barWidth: 3; live: root.focused }
        }

        RowLayout {
            visible: root.mode === "osd"
            anchors.centerIn: parent
            spacing: Theme.sp5
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
                radius: Theme.rXs
                color: Theme.surface1
                Rectangle {
                    width: parent.width * Math.min(1, Math.max(0, Island.flashData.value || 0))
                    height: parent.height
                    radius: Theme.rXs
                    color: (Island.flashData.value || 0) > 1 ? Theme.peach : Theme.accent
                    Behavior on width { NumberAnimation { duration: Theme.durFast } }
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
            spacing: Theme.sp5
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
            id: shotRow
            visible: root.mode === "shot"
            anchors.fill: parent
            anchors.margins: 10
            spacing: Theme.sp6
            readonly property string path: Island.flashData.path || ""

            HoverHandler { onHoveredChanged: Island.hold(hovered) }

            ClippingRectangle {
                Layout.preferredWidth: 112
                Layout.preferredHeight: 63
                radius: Theme.radius
                color: Theme.crust
                Image {
                    anchors.fill: parent
                    source: shotRow.path ? "file://" + shotRow.path : ""
                    sourceSize.width: 256
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.sp3
                Text {
                    text: "Screenshot copied"
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSize + 1
                    font.weight: Font.DemiBold
                }
                Row {
                    spacing: Theme.sp3
                    Repeater {
                        model: [["󰏫", "Edit"], ["󰊄", "Text"], ["󰉋", "Folder"], ["󰆴", "Delete"]]
                        Rectangle {
                            id: shotBtn
                            required property var modelData
                            width: shotLabel.implicitWidth + 30
                            height: 26
                            radius: 13
                            color: shotHover.hovered ? (modelData[1] === "Delete" ? Theme.red : Theme.accent) : Theme.surface0
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                Text { text: shotBtn.modelData[0]; color: shotHover.hovered ? Theme.crust : Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd; anchors.verticalCenter: parent.verticalCenter }
                                Text { id: shotLabel; text: shotBtn.modelData[1]; color: shotHover.hovered ? Theme.crust : Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; anchors.verticalCenter: parent.verticalCenter }
                            }
                            HoverHandler { id: shotHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    const p = Island.flashData.path || ""
                                    if (!p)
                                        return
                                    const what = shotBtn.modelData[1]
                                    if (what === "Edit")
                                        Quickshell.execDetached(["satty", "--filename", p, "--output-filename", p, "--early-exit", "--copy-command", "wl-copy"])
                                    else if (what === "Text")
                                        Quickshell.execDetached(["torus-ocr", p])
                                    else if (what === "Folder")
                                        Quickshell.execDetached(["xdg-open", p.substring(0, p.lastIndexOf("/"))])
                                    else if (what === "Delete")
                                        Quickshell.execDetached(["rm", "-f", "--", p])
                                    Island.dismiss()
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            visible: root.mode === "focus"
            anchors.centerIn: parent
            spacing: Theme.sp4
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
            visible: root.mode === "timer"
            anchors.centerIn: parent
            spacing: Theme.sp4
            Canvas {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                property real p: Timers.progress
                property bool sw: Timers.stopwatch
                onPChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d")
                    c.reset()
                    c.lineWidth = 2.5
                    c.strokeStyle = Theme.surface1
                    c.beginPath(); c.arc(8, 8, 6, 0, 2 * Math.PI); c.stroke()
                    c.strokeStyle = Timers.paused ? Theme.overlay : (sw ? Theme.teal : Theme.peach)
                    c.beginPath(); c.arc(8, 8, 6, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * (sw ? p : 1 - p)); c.stroke()
                }
            }
            Text {
                id: timerText
                text: (Timers.stopwatch ? "󱎫 " : "󰔛 ") + Timers.text + (Timers.label ? "  " + Timers.label : "") + (Timers.paused ? "  paused" : "")
                color: Timers.paused ? Theme.overlay : Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSize
            }
        }

        RowLayout {
            visible: root.mode === "recording"
            anchors.centerIn: parent
            spacing: Theme.sp4
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
