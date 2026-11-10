import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    property var items: []
    property string tab: "all"
    property string armed: ""
    property bool replayOn: false
    onArmedChanged: if (armed !== "") disarm.restart()

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }
    readonly property var shownItems: items.filter(i => tab === "all" || i.kind === tab)

    function refresh() {
        if (!lister.running)
            lister.running = true
    }

    function act(cmd) {
        Store.setOpen("capture", false)
        Quickshell.execDetached(["sh", "-c", "sleep 0.35; " + cmd])
    }

    function ago(t) {
        const m = Math.floor((Date.now() / 1000 - t) / 60)
        if (m < 1)
            return "just now"
        if (m < 60)
            return m + " min ago"
        if (m < 1440)
            return Math.floor(m / 60) + " h ago"
        return Qt.formatDate(new Date(t * 1000), "d MMM")
    }

    function size(b) {
        return b > 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB"
    }

    screen: Store.screenFor("capture")
    visible: Store.isOpen("capture") || motion.leaving
    onVisibleChanged: if (visible) {
        armed = ""
        refresh()
        if (!replayProc.running)
            replayProc.running = true
    }

    Process {
        id: replayProc
        command: ["torus-record", "replay-status"]
        stdout: StdioCollector { onStreamFinished: root.replayOn = text.trim() === "on" }
    }
    anchors.top: true
    margins.top: Store.barGap
    implicitWidth: Math.min(820, (screen ? screen.width : 900) - 40)
    implicitHeight: Math.min((screen ? screen.height : 900) - Store.barGap - 20, body.implicitHeight + 40)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("capture") && !Store.moving ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: Store.isOpen("capture")
        windows: [root]
        onCleared: Store.setOpen("capture", false)
    }

    Process {
        id: lister
        command: ["torus-captures", "24"]
        stdout: StdioCollector {
            onStreamFinished: root.items = text.split("\n").filter(l => l).map(l => {
                const f = l.split("\t")
                return { kind: f[0], time: Number(f[1]), size: Number(f[2]), path: f[3], thumb: f[4] }
            })
        }
    }

    Rectangle {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Store.setOpen("capture", false)
        PanelMotion {
            id: motion
            target: parent
            shown: Store.isOpen("capture") && !Store.moving
        }
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: 20
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body
                width: parent.width
                spacing: Theme.sp6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp5
                    Text { text: "󰄀"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 22 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { text: "Capture"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsTitle; font.weight: Font.DemiBold }
                        Text {
                            text: Island.recording ? "Recording now, stop it here or with SUPER+SHIFT+R" : "Screenshots go to ~/Pictures/Screenshots, recordings to ~/Videos"
                            color: Island.recording ? Theme.red : Theme.overlay
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSm
                        }
                    }
                    PanelButton {
                        visible: root.replayOn
                        icon: "󰓛"
                        label: "Stop instant replay"
                        implicitHeight: 30
                        onClicked: {
                            Quickshell.execDetached(["torus-record", "replay-stop"])
                            root.replayOn = false
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.width > 640 ? 4 : 2
                    columnSpacing: Theme.sp4
                    rowSpacing: Theme.sp4
                    Repeater {
                        model: [
                            ["󰩬", "Screenshot area", "select with the mouse", "torus-shot s", "Super P"],
                            ["󰹑", "Screenshot screen", "the monitor you are on", "torus-shot m", "Super Alt P"],
                            ["󰍺", "Screenshot all", "every monitor in one image", "torus-shot p", "Super Ctrl Alt P"],
                            ["󰊄", "Copy text", "select an area, its text goes to the clipboard", "torus-shot sc", "Super Ctrl S"],
                            ["󰑋", Island.recording ? "Stop recording" : "Record video", Island.recording ? "saves to ~/Videos" : "whole screen with sound", "torus-record toggle", "Super Shift R"],
                            ["󰕧", root.replayOn ? "Save last 60 s" : "Instant replay", root.replayOn ? "replay is running, this saves a clip" : "keeps the last 60 s in memory", "torus-record replay-save", "Super Alt R"],
                            ["󰒉", "Screenshot frozen", "freezes the screen, then select", "torus-shot sf", "Super Ctrl P"],
                            ["󰉋", "Open folder", "your screenshots", "xdg-open \"${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots\"", ""]
                        ]
                        Rectangle {
                            id: action
                            required property var modelData
                            readonly property bool rec: modelData[3] === "torus-record toggle" && Island.recording
                            property bool showKeys: false
                            Timer {
                                id: keyDelay
                                interval: 1500
                                onTriggered: action.showKeys = actHover.hovered
                            }
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: Theme.rCard
                            color: actHover.hovered ? Qt.alpha(rec ? Theme.red : Theme.accent, 0.18) : Theme.surface0
                            border.width: 1
                            border.color: actHover.hovered ? (rec ? Theme.red : Theme.accent) : Qt.alpha(Theme.surface1, 0.6)
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            scale: actTap.pressed ? 0.96 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: Theme.sp5
                                Text { text: action.modelData[0]; color: action.rec ? Theme.red : Theme.accent; font.family: Theme.fontMono; font.pixelSize: 22 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text { Layout.fillWidth: true; text: action.modelData[1]; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.sp1
                                        Text { Layout.fillWidth: true; visible: !action.showKeys; text: action.modelData[2]; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsXs; elide: Text.ElideRight }
                                        Repeater {
                                            model: action.showKeys && action.modelData[4] ? action.modelData[4].split(" ") : []
                                            Rectangle {
                                                required property string modelData
                                                implicitWidth: keyText.implicitWidth + 8
                                                implicitHeight: 16
                                                radius: 4
                                                color: Qt.alpha(Theme.crust, 0.6)
                                                border.width: 1
                                                border.color: Qt.alpha(Theme.surface1, 0.8)
                                                Text { id: keyText; anchors.centerIn: parent; text: parent.modelData; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: 9 }
                                            }
                                        }
                                    }
                                }
                            }
                            HoverHandler {
                                id: actHover
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: {
                                    if (hovered) {
                                        keyDelay.restart()
                                    } else {
                                        keyDelay.stop()
                                        action.showKeys = false
                                    }
                                }
                            }
                            TapHandler { id: actTap; onTapped: root.act(action.modelData[3]) }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Recent"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2; font.capitalization: Font.AllUppercase }
                    Item { Layout.fillWidth: true }
                    Segmented {
                        options: ["all", "image", "video"]
                        labels: ["All", "Screenshots", "Recordings"]
                        current: root.tab
                        onPicked: value => root.tab = value
                    }
                }

                Text {
                    visible: root.shownItems.length === 0
                    text: "Nothing captured yet."
                    color: Theme.subtext
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.sp4
                    Repeater {
                        model: root.shownItems
                        Rectangle {
                            id: shot
                            required property var modelData
                            readonly property real w: (body.width - 3 * Theme.sp4) / 4
                            width: w
                            height: w * 0.62 + 34
                            radius: Theme.rCard
                            color: Theme.mantle
                            border.width: 1
                            border.color: shotHover.hovered ? Theme.accent : Qt.alpha(Theme.surface1, 0.6)
                            clip: true

                            Image {
                                id: pic
                                x: 4
                                y: 4
                                width: parent.width - 8
                                height: shot.w * 0.62 - 4
                                source: shot.modelData.thumb ? "file://" + shot.modelData.thumb : ""
                                sourceSize.width: 400
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }
                            Text {
                                visible: pic.status !== Image.Ready
                                anchors.centerIn: pic
                                text: shot.modelData.kind === "video" ? "󰕧" : "󰋩"
                                color: Theme.overlay
                                font.family: Theme.fontMono
                                font.pixelSize: 26
                            }
                            Rectangle {
                                visible: shot.modelData.kind === "video"
                                anchors.centerIn: pic
                                width: 34
                                height: 34
                                radius: 17
                                color: Qt.alpha(Theme.crust, 0.7)
                                Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; text: "󰐊"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsXl }
                            }
                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 8
                                spacing: Theme.sp2
                                Text { Layout.fillWidth: true; text: root.ago(shot.modelData.time); color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsXs; elide: Text.ElideRight }
                                Text { text: root.size(shot.modelData.size); color: Theme.overlay; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs }
                            }

                            HoverHandler {
                                id: shotHover
                                onHoveredChanged: if (!hovered && root.armed === shot.modelData.path) root.armed = ""
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Store.setOpen("capture", false)
                                    Quickshell.execDetached(["xdg-open", shot.modelData.path])
                                }
                            }

                            Row {
                                visible: shotHover.hovered
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                spacing: 4
                                Repeater {
                                    model: shot.modelData.kind === "image" ? [["󰆏", "copy"], ["󰏫", "edit"], ["󰊄", "text"], ["󰉋", "folder"], ["󰆴", "delete"]] : [["󰆏", "copy"], ["󰉋", "folder"], ["󰆴", "delete"]]
                                    Rectangle {
                                        id: mini
                                        required property var modelData
                                        readonly property bool danger: modelData[1] === "delete"
                                        readonly property bool armedHere: danger && root.armed === shot.modelData.path
                                        width: 26
                                        height: 26
                                        radius: 13
                                        color: miniHover.hovered || armedHere ? (danger ? Theme.red : Theme.accent) : Qt.alpha(Theme.crust, 0.8)
                                        Behavior on width { NumberAnimation { duration: Theme.durFast } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: mini.armedHere ? "󰄬" : mini.modelData[0]
                                            color: miniHover.hovered || mini.armedHere ? Theme.crust : Theme.text
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fsMd
                                        }
                                        MouseArea {
                                            id: miniHover
                                            readonly property bool hovered: containsMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const p = shot.modelData.path
                                                const what = mini.modelData[1]
                                                if (what === "copy")
                                                    Quickshell.execDetached(shot.modelData.kind === "image" ? ["sh", "-c", "wl-copy < \"$1\"", "sh", p] : ["sh", "-c", "printf 'file://%s\\n' \"$1\" | wl-copy -t text/uri-list", "sh", p])
                                                else if (what === "edit")
                                                    root.act("satty --filename '" + p.replace(/'/g, "'\\''") + "' --early-exit --copy-command wl-copy")
                                                else if (what === "text")
                                                    Quickshell.execDetached(["sh", "-c", "tesseract \"$1\" - -l eng 2> /dev/null | wl-copy && notify-send -a torus 'Text copied' 'from the screenshot'", "sh", p])
                                                else if (what === "folder")
                                                    Quickshell.execDetached(["xdg-open", p.substring(0, p.lastIndexOf("/"))])
                                                else if (what === "delete") {
                                                    if (root.armed !== p) {
                                                        root.armed = p
                                                        return
                                                    }
                                                    root.armed = ""
                                                    Quickshell.execDetached(["rm", "-f", "--", p])
                                                    root.items = root.items.filter(i => i.path !== p)
                                                }
                                                if (what === "copy")
                                                    Quickshell.execDetached(["notify-send", "-a", "torus", "-u", "low", "Copied", p.split("/").pop()])
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
