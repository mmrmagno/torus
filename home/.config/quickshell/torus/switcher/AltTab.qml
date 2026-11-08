import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

PanelWindow {
    id: root

    property int selected: 0
    readonly property var windows: Hyprland.toplevels.values.slice().sort((a, b) => ((a.lastIpcObject || {}).focusHistoryID || 0) - ((b.lastIpcObject || {}).focusHistoryID || 0))

    function step(dir) {
        if (windows.length === 0)
            return
        if (!Store.isOpen("alttab")) {
            Hyprland.refreshToplevels()
            selected = windows.length > 1 ? 1 : 0
            Store.setOpen("alttab", true)
            return
        }
        selected = (selected + (dir === "prev" ? -1 : 1) + windows.length) % windows.length
    }

    function apply() {
        if (!Store.isOpen("alttab"))
            return
        const w = windows[selected]
        Store.setOpen("alttab", false)
        if (w && w.wayland)
            w.wayland.activate()
    }

    screen: Store.focusedScreen
    visible: Store.isOpen("alttab")
    implicitWidth: Math.min((screen ? screen.width : 1200) - 80, windows.length * 252 + 32)
    implicitHeight: 220
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay

    Component.onCompleted: Store.altTabber = root

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
        color: Qt.alpha(Theme.base, 0.92)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        clip: true

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 12

            Repeater {
                model: root.windows
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === root.selected
                    width: 240
                    height: 180
                    radius: 12
                    color: sel ? Qt.alpha(Theme.accent, 0.2) : Theme.surface0
                    border.width: sel ? 2 : 0
                    border.color: Theme.accent
                    ScreencopyView {
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.bottomMargin: 30
                        captureSource: parent.modelData.wayland
                        live: root.visible
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
