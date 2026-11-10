import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs

PanelWindow {
    id: root

    property int selected: 0
    property real releasedAt: 0
    property bool revealed: false
    property var mru: []
    readonly property var windows: {
        const rank = t => {
            const i = mru.indexOf(t.address)
            return i >= 0 ? i : 1000 + ((t.lastIpcObject || {}).focusHistoryID || 0)
        }
        return Hyprland.toplevels.values.slice().sort((a, b) => rank(a) - rank(b))
    }

    property string query: ""
    readonly property var shown: {
        const q = query.toLowerCase()
        if (q === "")
            return windows
        return windows.filter(t => {
            const app = t.wayland && t.wayland.appId ? t.wayland.appId : ""
            const e = app ? DesktopEntries.heuristicLookup(app) : null
            return ((t.title || "") + " " + app + " " + (e ? e.name : "")).toLowerCase().includes(q)
        })
    }
    onShownChanged: if (selected >= shown.length) selected = Math.max(0, shown.length - 1)

    function type(text) {
        query = text
        const cur = Hyprland.activeToplevel
        selected = shown.length > 1 && cur && shown[0].address === cur.address ? 1 : 0
    }

    function noteFocus() {
        const t = Hyprland.activeToplevel
        if (t && t.address)
            mru = [t.address].concat(mru.filter(a => a !== t.address)).slice(0, 200)
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            root.noteFocus()
        }
    }

    function step(dir) {
        if (windows.length === 0)
            return
        if (!Store.isOpen("alttab")) {
            if (Date.now() - releasedAt < 1500) {
                releasedAt = 0
                Store.focusWindow(windows.length > 1 ? windows[1] : null)
                return
            }
            Hyprland.refreshToplevels()
            query = ""
            selected = windows.length > 1 ? 1 : 0
            revealed = false
            reveal.restart()
            Store.setOpen("alttab", true)
            return
        }
        const n = Math.max(1, shown.length)
        selected = (selected + (dir === "prev" ? -1 : 1) + n) % n
    }

    function apply() {
        if (!Store.isOpen("alttab")) {
            releasedAt = Date.now()
            return
        }
        const w = shown[selected]
        Store.setOpen("alttab", false)
        query = ""
        Store.focusWindow(w)
    }

    screen: Store.focusedScreen
    visible: Store.isOpen("alttab") && revealed
    readonly property int count: Math.max(1, shown.length)
    readonly property int head: 30
    readonly property int maxW: (screen ? screen.width : 1200) - 80
    readonly property int maxH: (screen ? screen.height : 800) - 160
    readonly property int tileW: {
        for (let w = 240; w > 120; w -= 10) {
            const cols = Math.max(1, Math.floor((maxW - 20) / (w + 12)))
            if (Math.ceil(count / cols) * (Math.round(w * 0.75) + 12) + 20 <= maxH)
                return w
        }
        return 120
    }
    readonly property int tileH: Math.round(tileW * 0.75)
    readonly property int cols: Math.max(1, Math.min(count, Math.floor((maxW - 20) / (tileW + 12))))
    readonly property int rows: Math.ceil(count / cols)

    implicitWidth: cols * (tileW + 12) - 12 + 32
    implicitHeight: rows * (tileH + 12) - 12 + 32 + head
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Component.onCompleted: {
        Store.altTabber = root
        noteFocus()
    }

    Timer {
        id: reveal
        interval: 110
        onTriggered: root.revealed = Store.isOpen("alttab")
    }

    Loader {
        anchors.fill: parent
        active: root.visible
        sourceComponent: content
    }

    Component {
        id: content
    Rectangle {
        anchors.fill: parent
        radius: Theme.rPanel
        opacity: 0
        scale: 0.96
        Component.onCompleted: {
            opacity = 1
            scale = 1
            forceActiveFocus()
        }
        Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        color: Qt.alpha(Theme.base, Theme.glass)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        clip: true
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Backspace) {
                root.type(root.query.slice(0, -1))
            } else if (event.key === Qt.Key_Escape) {
                root.query = ""
                Store.setOpen("alttab", false)
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.apply()
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                root.step("prev")
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                root.step("next")
            } else if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) {
                root.type(root.query + String.fromCharCode(event.key + 32))
            } else if ((event.key >= Qt.Key_0 && event.key <= Qt.Key_9) || event.key === Qt.Key_Space || event.key === Qt.Key_Minus || event.key === Qt.Key_Period) {
                root.type(root.query + String.fromCharCode(event.key))
            } else {
                return
            }
            event.accepted = true
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 12
            spacing: Theme.sp3
            Text {
                text: "󰍉"
                color: root.query !== "" ? Theme.accent : Theme.overlay
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsMd
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.query !== "" ? root.query + (root.shown.length === 0 ? "  ·  no match" : "") : "type to filter"
                color: root.query !== "" ? (root.shown.length === 0 ? Theme.red : Theme.text) : Theme.overlay
                font.family: root.query !== "" ? Theme.fontMono : Theme.fontUi
                font.pixelSize: Theme.fsMd
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Grid {
            id: row
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.head / 2
            spacing: Theme.sp6
            columns: root.cols

            Repeater {
                model: root.shown
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === root.selected
                    width: root.tileW
                    height: root.tileH
                    radius: Theme.rCard
                    color: sel ? Qt.alpha(Theme.accent, 0.2) : Theme.surface0
                    border.width: sel ? 2 : 0
                    border.color: Theme.accent
                    IconImage {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -10
                        implicitSize: Math.round(parent.height * 0.32)
                        source: {
                            const app = parent.modelData.wayland && parent.modelData.wayland.appId ? parent.modelData.wayland.appId : ""
                            const e = app ? DesktopEntries.heuristicLookup(app) : null
                            return Quickshell.iconPath(e ? e.icon : "", "application-x-executable")
                        }
                    }
                    ScreencopyView {
                        id: shot
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.bottomMargin: 30
                        captureSource: parent.modelData.wayland
                        live: root.visible
                        constraintSize: Qt.size(width, height)
                        opacity: hasContent ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                    }
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 16
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        text: parent.modelData.title
                        color: parent.sel ? Theme.text : Theme.subtext
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsMd
                    }
                }
            }
        }
    }
    }
}
