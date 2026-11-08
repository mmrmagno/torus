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
    readonly property var windows: Hyprland.toplevels.values.slice().sort((a, b) => ((a.lastIpcObject || {}).focusHistoryID || 0) - ((b.lastIpcObject || {}).focusHistoryID || 0))

    function step(dir) {
        if (windows.length === 0)
            return
        if (!Store.isOpen("alttab")) {
            if (Date.now() - releasedAt < 400) {
                releasedAt = 0
                const w = windows.length > 1 ? windows[1] : null
                if (w && w.wayland)
                    w.wayland.activate()
                return
            }
            Hyprland.refreshToplevels()
            selected = windows.length > 1 ? 1 : 0
            revealed = false
            reveal.restart()
            Store.setOpen("alttab", true)
            return
        }
        selected = (selected + (dir === "prev" ? -1 : 1) + windows.length) % windows.length
    }

    function apply() {
        if (!Store.isOpen("alttab")) {
            releasedAt = Date.now()
            return
        }
        const w = windows[selected]
        Store.setOpen("alttab", false)
        if (w && w.wayland)
            w.wayland.activate()
    }

    screen: Store.focusedScreen
    visible: Store.isOpen("alttab") && revealed
    readonly property int count: Math.max(1, windows.length)
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
    implicitHeight: rows * (tileH + 12) - 12 + 32
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay

    Component.onCompleted: Store.altTabber = root

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
        radius: 18
        opacity: 0
        scale: 0.96
        Component.onCompleted: {
            opacity = 1
            scale = 1
        }
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        color: Qt.alpha(Theme.base, Theme.glass)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        clip: true

        Grid {
            id: row
            anchors.centerIn: parent
            spacing: 12
            columns: root.cols

            Repeater {
                model: root.windows
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === root.selected
                    width: root.tileW
                    height: root.tileH
                    radius: 12
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
                        Behavior on opacity { NumberAnimation { duration: 120 } }
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
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
    }
}
