import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

PanelWindow {
    id: root

    property var groups: []

    function mods(m) {
        const out = []
        if (m & 64) out.push("SUPER")
        if (m & 4) out.push("CTRL")
        if (m & 8) out.push("ALT")
        if (m & 1) out.push("SHIFT")
        return out
    }

    screen: Store.focusedScreen
    visible: Store.isOpen("cheatsheet")
    onVisibleChanged: if (visible) proc.running = true
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Process {
        id: proc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const by = {}
                for (const b of JSON.parse(text)) {
                    const m = (b.description || "").match(/^\[([^\]|]+)/)
                    if (!m || /workspace [0-9]/.test(b.description))
                        continue
                    const g = m[1]
                    const keys = root.mods(b.modmask).concat([b.key]).join(" + ")
                    ;(by[g] = by[g] || []).push({ keys: keys, what: b.description.replace(/^\[[^\]]*\]\s*/, "") })
                }
                root.groups = Object.keys(by).map(g => ({ name: g, items: by[g] }))
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.crust, 0.75)
        focus: true
        Keys.onPressed: Store.setOpen("cheatsheet", false)
        TapHandler { onTapped: Store.setOpen("cheatsheet", false) }

        Flickable {
            anchors.fill: parent
            anchors.margins: 40
            contentHeight: flow.implicitHeight
            clip: true

            Flow {
                id: flow
                width: parent.width
                spacing: 24

                Repeater {
                    model: root.groups
                    Column {
                        required property var modelData
                        width: 380
                        spacing: 4
                        Text {
                            text: modelData.name
                            color: Theme.accent
                            font.family: Theme.fontUi
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            bottomPadding: 4
                        }
                        Repeater {
                            model: modelData.items
                            Row {
                                required property var modelData
                                spacing: 10
                                Text { text: modelData.keys; width: 180; color: Theme.lavender; font.family: Theme.fontMono; font.pixelSize: 11; elide: Text.ElideRight }
                                Text { text: modelData.what; width: 190; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: 11; elide: Text.ElideRight }
                            }
                        }
                    }
                }
            }
        }
    }
}
