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
    property var mics: []
    property string mic: ""
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

    property int sel: -1
    property string keptSel: ""
    property bool placing: false
    Binding {
        target: Store
        property: "captureTab"
        value: root.tab
    }
    property bool setting: false
    property string look: ""
    onShownItemsChanged: if (sel >= shownItems.length) sel = shownItems.length - 1
    onSelChanged: {
        Store.captureSel = sel >= 0 && sel < shownItems.length ? shownItems[sel].path : ""
        const t = sel >= 0 ? tiles.itemAt(sel) : null
        if (!t)
            return
        const y = t.mapToItem(body, 0, 0).y
        if (y < flick.contentY)
            flick.contentY = Math.max(0, y - 8)
        else if (y + t.height > flick.contentY + flick.height)
            flick.contentY = y + t.height - flick.height + 16
    }

    function move(dx, dy) {
        const n = shownItems.length
        if (n === 0)
            return false
        if (sel < 0) {
            if (dy > 0 || dx > 0) {
                sel = 0
                capFrame.forceActiveFocus()
                return true
            }
            return false
        }
        const next = sel + dx + dy * 4
        if (next < 0)
            sel = dy < 0 ? -1 : 0
        else
            sel = Math.min(n - 1, next)
        return true
    }

    property var healed: ({})

    function thumbLost(path) {
        if (healed[path])
            return
        const h = Object.assign({}, healed)
        h[path] = true
        healed = h
        refresh()
    }

    function tileAct(item, what) {
        const p = item.path
        if (what === "disarm") {
            if (armed === p)
                armed = ""
        } else if (what === "open") {
            Store.setOpen("capture", false)
            Quickshell.execDetached(["torus-launch", "xdg-open", p])
        } else if (what === "copy") {
            Quickshell.execDetached(item.kind === "image" ? ["sh", "-c", "wl-copy < \"$1\"", "sh", p] : ["sh", "-c", "printf 'file://%s\\n' \"$1\" | wl-copy -t text/uri-list", "sh", p])
            Quickshell.execDetached(["notify-send", "-a", "torus", "-u", "low", "Copied", p.split("/").pop()])
        } else if (what === "cut") {
            Store.pendingCut = p
            Store.setOpen("capture", false)
            Store.setOpen("games", true)
        } else if (what === "edit") {
            act("satty --filename '" + p.replace(/'/g, "'\\''") + "' --early-exit --copy-command wl-copy")
        } else if (what === "text") {
            Quickshell.execDetached(["torus-ocr", p])
        } else if (what === "folder") {
            Quickshell.execDetached(["torus-launch", "xdg-open", p.substring(0, p.lastIndexOf("/"))])
        } else if (what === "delete") {
            if (item.fav) {
                Store.sound("error")
                return
            }
            if (armed !== p) {
                armed = p
                return
            }
            armed = ""
            Store.trash(p)
            items = items.filter(i => i.path !== p)
        }
    }

    Connections {
        target: Store
        function onRestored() {
            if (root.visible)
                root.refresh()
        }
    }

    function act(cmd) {
        Store.setOpen("capture", false)
        Quickshell.execDetached(["torus-launch", "sh", "-c", "sleep 0.35; " + cmd])
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
        if (!micsProc.running)
            micsProc.running = true
    }

    function pickMic(name) {
        mic = name
        Quickshell.execDetached(["torus-record", "replay-mic", name === "" ? "off" : name])
    }

    Process {
        id: micsProc
        command: ["sh", "-c", "torus-record replay-mic; echo; torus-record replay-mics"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                root.mic = (lines.shift() || "").trim()
                root.mics = lines.filter(l => l.indexOf("\t") > 0).map(l => {
                    const parts = l.split("\t")
                    const name = parts[0]
                    const label = parts[1] || name
                    return { name: name, label: name === "default_input" ? "Default mic" : label.replace(/ Analog Stereo| Digital Stereo.*$/, "") }
                })
            }
        }
    }

    Process {
        id: replayProc
        command: ["torus-record", "replay-status"]
        stdout: StdioCollector { onStreamFinished: root.replayOn = text.trim() === "on" }
    }
    anchors.top: true
    margins.top: Store.barGap
    implicitWidth: Math.min(820, (screen ? screen.width : 900) - 40)
    implicitHeight: Store.panelRoom(screen, 20)
    mask: Region { item: capFrame }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("capture") && !Store.moving ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: Store.isOpen("capture") && root.backingWindowVisible
        windows: [root]
        onCleared: Store.setOpen("capture", false)
    }

    Process {
        id: lister
        command: ["torus-captures", "40"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.items = text.split("\n").filter(l => l).map(l => {
                    const f = l.split("\t")
                    return { kind: f[0], time: Number(f[1]), size: Number(f[2]), path: f[3], thumb: f[4], fav: f[5] === "1" }
                })
                if (root.placing) {
                    root.placing = false
                    root.sel = root.shownItems.findIndex(i => i.path === root.keptSel)
                }
            }
        }
    }

    Rectangle {
        id: capFrame
        Connections {
            target: root
            function onVisibleChanged() {
                if (root.visible) {
                    if (!Store.recalls("capture")) {
                        root.tab = "all"
                        root.keptSel = ""
                    }
                    root.setting = false
                    root.look = ""
                    root.sel = -1
                    root.placing = root.keptSel !== ""
                    capFrame.forceActiveFocus()
                } else {
                    root.keptSel = root.sel >= 0 && root.sel < root.shownItems.length ? root.shownItems[root.sel].path : ""
                }
            }
        }
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(body.implicitHeight + 40 + hintBar.height + Theme.sp5, root.implicitHeight)
        Behavior on height { enabled: root.visible; NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
        transformOrigin: Item.Top
        focus: true
        Keys.onEscapePressed: root.look !== "" ? root.look = "" : (root.setting ? root.setting = false : Store.setOpen("capture", false))
        Keys.onPressed: event => {
            const cur = root.sel >= 0 ? root.shownItems[root.sel] : null
            const ctrl = event.modifiers & Qt.ControlModifier
            if (root.setting) {
                capSheet.key(event)
                event.accepted = true
                return
            }
            if (root.look !== "") {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Up)
                    root.move(-1, 0)
                else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down)
                    root.move(1, 0)
                const now = root.sel >= 0 ? root.shownItems[root.sel] : null
                root.look = (event.key === Qt.Key_Space || event.key === Qt.Key_Escape || !now) ? "" : now.path
                event.accepted = true
                return
            }
            if (cur && event.key === Qt.Key_Space) {
                root.look = cur.path
                event.accepted = true
                return
            }
            if (ctrl && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                root.setting = true
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Left)
                event.accepted = root.move(-1, 0)
            else if (event.key === Qt.Key_Right)
                event.accepted = root.move(1, 0)
            else if (event.key === Qt.Key_Up)
                event.accepted = root.move(0, -1)
            else if (event.key === Qt.Key_Down)
                event.accepted = root.move(0, 1)
            else if (ctrl && event.key === Qt.Key_Z)
                Island.trashUndo()
            else if (event.key === Qt.Key_BracketRight || event.key === Qt.Key_BracketLeft) {
                const tabs = ["all", "image", "video", "clip"]
                root.tab = tabs[(tabs.indexOf(root.tab) + (event.key === Qt.Key_BracketRight ? 1 : 3)) % 4]
                root.sel = -1
            } else if (!cur)
                return
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.tileAct(cur, "open")
            else if (ctrl && event.key === Qt.Key_C)
                root.tileAct(cur, "copy")
            else if (ctrl && event.key === Qt.Key_E)
                root.tileAct(cur, cur.kind === "image" ? "edit" : "cut")
            else if (event.key === Qt.Key_Delete)
                root.tileAct(cur, "delete")
            else
                return
            event.accepted = true
        }
        PanelMotion {
            id: motion
            target: capFrame
            shown: Store.isOpen("capture") && !Store.moving
        }
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        clip: true

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 15
            anchors.bottomMargin: 15 + hintBar.height + Theme.sp5
            contentHeight: body.implicitHeight + 10
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body
                x: 5
                y: 5
                width: parent.width - 10
                spacing: Theme.sp6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp5
                    Text { text: "󰄀"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 22 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { Layout.fillWidth: true; text: "Capture"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsTitle; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Island.recording ? "Recording now, stop it here or with SUPER+SHIFT+R" : "Screenshots go to ~/Pictures/Screenshots, recordings to ~/Videos, game clips to ~/Videos/Clips"
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
                    PanelButton {
                        icon: "󰒓"
                        label: ""
                        implicitHeight: 30
                        onClicked: root.setting = true
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
                            ["󰕧", root.replayOn ? "Save last 60 s" : "Instant replay", root.replayOn ? "replay is running, this saves a clip" : (root.mic ? "last 60 s in memory, with your mic" : "keeps the last 60 s in memory"), "torus-record replay-save", "Super Alt R"],
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
                        options: ["all", "image", "video", "clip"]
                        labels: ["All", "Screenshots", "Recordings", "Game clips"]
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
                        id: tiles
                        model: root.shownItems
                        CaptureTile {
                            id: shot
                            required property var modelData
                            required property int index
                            selected: root.sel === index
                            readonly property real w: (body.width - 3 * Theme.sp4) / 4
                            width: w
                            height: w * 0.62 + 34
                            path: shot.modelData.path
                            kind: shot.modelData.kind === "image" ? "image" : "video"
                            cuttable: shot.modelData.kind !== "image"
                            starred: shot.modelData.fav
                            caption: shot.modelData.kind === "clip" ? shot.modelData.path.split("/").slice(-2, -1)[0] : ""
                            thumb: shot.modelData.thumb || ""
                            time: shot.modelData.time
                            bytes: shot.modelData.size
                            armed: root.armed === shot.modelData.path
                            onOpened: root.tileAct(shot.modelData, "open")
                            onThumbLost: root.thumbLost(shot.modelData.path)
                            onAct: what => root.tileAct(shot.modelData, what)
                        }
                    }
                }
            }
        }

        ScrollFade { flick: flick }

        KeyHints {
            id: hintBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 15
            hints: root.sel >= 0 ? [["← / → / ↑ / ↓", "pick"], ["Space", "look"], ["↵", "open"], ["Ctrl C", "copy"], ["Ctrl E", "edit"], ["Del", "trash"], ["Esc", "close"]]
                : [["↓", "captures"], ["[ ]", "kind"], ["Ctrl ↵", "settings"], ["Tab", "buttons"], ["↵", "press"], ["Esc", "close"]]
        }

        QuickLook {
            anchors.fill: parent
            z: 58
            path: root.look
            kind: root.sel >= 0 && root.shownItems[root.sel] && root.shownItems[root.sel].kind !== "image" ? "video" : "image"
            onClosed: root.look = ""
        }

        SettingsSheet {
            id: capSheet
            anchors.fill: parent
            z: 60
            visible: root.setting
            title: "Capture settings"
            note: "Screenshots go to ~/Pictures/Screenshots, recordings to ~/Videos, game clips to ~/Videos/Clips"
            rows: [{ key: "mic", label: "Mic in instant replay", note: root.mics.length > 0 ? "your voice in the clips the replay buffer saves" : "no microphone found", values: [""].concat(root.mics.map(m => m.name)), labels: ["Off"].concat(root.mics.map(m => m.label)) }]
            values: ({ mic: root.mic })
            onPicked: (key, value) => root.pickMic(value)
            moreHints: capTrash.count > 0 ? [["Del", capTrash.armed ? "again: empty for good" : "empty trash"]] : []
            onDeletePressed: capTrash.empty()
            TrashMeter { id: capTrash; Layout.fillWidth: true }
            onClosed: {
                root.setting = false
                capFrame.forceActiveFocus()
            }
        }
    }
}
