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
    readonly property bool flashing: Island.state === "osd" || Island.state === "notification" || Island.state === "shot" || Island.state === "trash"
    readonly property string resting: Island.recording ? "recording" : Island.sharing ? "sharing" : (SteamLog.top || BrowserDownloads.top ? "progress" : (Timers.running ? "timer" : (Focus.running ? "focus" : (narrow ? "" : (Island.player && Feel.islandOn("music") ? "media" : "idle")))))
    readonly property bool faceOn: FaceScan.state !== "idle"
    readonly property string mode: faceOn && focused ? "face" : (flashing && focused ? Island.state : resting)
    readonly property bool lyricRow: mode === "media" && Lyrics.line !== ""
    readonly property int pillWidth: {
        switch (mode) {
        case "face": return Math.max(190, faceText.implicitWidth + 64)
        case "osd": return 300
        case "notification": return 440
        case "shot": return 460
        case "trash": return 400
        case "recording": return Math.max(170, recText.implicitWidth + 56)
        case "sharing": return Math.max(190, shareText.implicitWidth + 56)
        case "progress": return Math.max(220, progText.implicitWidth + 60)
        case "focus": return 150
        case "timer": return Math.max(150, timerText.implicitWidth + 56)
        case "media": return lyricRow ? 440 : 380
        case "idle": return Math.min(360, Math.max(170, idleText.implicitWidth + 64))
        default: return 0
        }
    }
    readonly property int pillHeight: mode === "notification" ? 56 : (mode === "shot" ? 92 : Store.barHeight)

    property var osdData: ({})
    property var noteData: ({})
    property var shotData: ({})
    Binding { target: root; property: "osdData"; value: Island.flashData; when: root.mode === "osd"; restoreMode: Binding.RestoreNone }
    Binding { target: root; property: "noteData"; value: Island.flashData; when: root.mode === "notification"; restoreMode: Binding.RestoreNone }
    Binding { target: root; property: "shotData"; value: Island.flashData; when: root.mode === "shot"; restoreMode: Binding.RestoreNone }
    property var trashData: ({})
    Binding { target: root; property: "trashData"; value: Island.flashData; when: root.mode === "trash"; restoreMode: Binding.RestoreNone }

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
        border.color: root.mode === "face" ? (FaceScan.state === "fail" ? Qt.alpha(Theme.red, 0.8) : FaceScan.state === "ok" ? Qt.alpha(Theme.green, 0.8) : Qt.alpha(Theme.accent, 0.6)) : root.mode === "recording" ? Qt.alpha(Theme.red, 0.7) : root.mode === "sharing" ? Qt.alpha(Theme.peach, 0.7) : Qt.alpha(Theme.accent, 0.35)
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
            opacity: root.mode === "face" ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.mode === "face" ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: root.mode === "face" ? Theme.durMed : Theme.durFast; easing.type: Easing.OutCubic } }
            anchors.centerIn: parent
            spacing: Theme.sp5
            FaceRing {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                phase: FaceScan.state
            }
            Text {
                id: faceText
                text: FaceScan.state === "ok" ? "Recognized" : FaceScan.state === "fail" ? (FaceScan.reason === "too dark" ? "Too dark" : "Not recognized") : "Looking for you"
                color: FaceScan.state === "fail" ? Theme.red : Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSize
            }
        }

        RowLayout {
            opacity: root.mode === "idle" ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.mode === "idle" ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: root.mode === "idle" ? Theme.durMed : Theme.durFast; easing.type: Easing.OutCubic } }
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
            opacity: root.mode === "media" ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.mode === "media" ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: root.mode === "media" ? Theme.durMed : Theme.durFast; easing.type: Easing.OutCubic } }
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
            opacity: root.mode === "osd" ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.mode === "osd" ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: root.mode === "osd" ? Theme.durMed : Theme.durFast; easing.type: Easing.OutCubic } }
            anchors.centerIn: parent
            spacing: Theme.sp5
            Text {
                text: root.osdData.icon || ""
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSize + 3
            }
            Rectangle {
                visible: root.osdData.value !== undefined && root.osdData.value >= 0
                Layout.preferredWidth: 150
                Layout.preferredHeight: 6
                radius: Theme.rXs
                color: Theme.surface1
                Rectangle {
                    width: parent.width * Math.min(1, Math.max(0, root.osdData.value || 0))
                    height: parent.height
                    radius: Theme.rXs
                    color: (root.osdData.value || 0) > 1 ? Theme.peach : Theme.accent
                    Behavior on width { NumberAnimation { duration: Theme.durFast } }
                }
            }
            Text {
                text: root.osdData.label || ""
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSize
            }
        }

        RowLayout {
            opacity: root.mode === "notification" ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.mode === "notification" ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: root.mode === "notification" ? Theme.durMed : Theme.durFast; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 16
            spacing: Theme.sp5
            NotifIcon {
                size: 28
                image: root.noteData.image || ""
                appIcon: root.noteData.icon || ""
                app: root.noteData.app || ""
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: root.noteData.summary || ""
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSize + 1
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.noteData.body || root.noteData.app || ""
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
            opacity: root.mode === "shot" ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.mode === "shot" ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: root.mode === "shot" ? Theme.durMed : Theme.durFast; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.margins: 10
            spacing: Theme.sp6
            readonly property string path: root.shotData.path || ""

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
                            TapHandler { onTapped: Island.shotAct(shotBtn.modelData[1]) }
                        }
                    }
                }
            }
        }

        TrashFace {
            opacity: root.mode === "trash" ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.mode === "trash" ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: root.mode === "trash" ? Theme.durMed : Theme.durFast; easing.type: Easing.OutCubic } }
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            info: root.trashData
            onUndo: Island.trashUndo()
            HoverHandler { onHoveredChanged: Island.hold(hovered) }
        }

        RowLayout {
            opacity: root.mode === "focus" ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.mode === "focus" ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: root.mode === "focus" ? Theme.durMed : Theme.durFast; easing.type: Easing.OutCubic } }
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
            opacity: root.mode === "timer" ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.mode === "timer" ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: root.mode === "timer" ? Theme.durMed : Theme.durFast; easing.type: Easing.OutCubic } }
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
            opacity: root.mode === "sharing" ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.mode === "sharing" ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: root.mode === "sharing" ? Theme.durMed : Theme.durFast; easing.type: Easing.OutCubic } }
            anchors.centerIn: parent
            spacing: Theme.sp4
            Rectangle {
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                radius: 5
                color: Theme.peach
                SequentialAnimation on opacity {
                    running: root.mode === "sharing"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 900 }
                    NumberAnimation { to: 1; duration: 900 }
                }
            }
            Text {
                id: shareText
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSize
                text: "Sharing · " + Island.shareApps.join(", ")
            }
        }

        RowLayout {
            opacity: root.mode === "progress" ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.mode === "progress" ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: root.mode === "progress" ? Theme.durMed : Theme.durFast; easing.type: Easing.OutCubic } }
            anchors.centerIn: parent
            spacing: Theme.sp4
            ProgressRing {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                readonly property var job: SteamLog.top || BrowserDownloads.top
                value: job ? (job.pct < 0 ? -1 : job.pct / 100) : 0
                tint: job && job.kind !== "shader" ? Theme.sapphire : Theme.accent
            }
            Text {
                id: progText
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSize
                text: {
                    const j = SteamLog.top || BrowserDownloads.top
                    if (!j)
                        return ""
                    if (j.kind === "browser")
                        return j.name + "  ·  " + j.size + (j.speed ? "  ·  " + j.speed : "")
                    const what = j.kind === "download" ? (j.speed || "downloading") : "shaders"
                    const left = SteamLog.left(j.left)
                    return j.name + "  ·  " + what + " " + j.pct + "%" + (left ? "  ·  " + left : "")
                }
            }
        }

        RowLayout {
            opacity: root.mode === "recording" ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.mode === "recording" ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: root.mode === "recording" ? Theme.durMed : Theme.durFast; easing.type: Easing.OutCubic } }
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
                        recText.text = "REC " + String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0") + (Island.sharing ? "  ·  sharing" : "")
                    }
                }
            }
        }
    }
}
