import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

PanelWindow {
    id: root

    property var all: []
    property string query: ""
    readonly property var groups: {
        const words = query.toLowerCase().split(/\s+/).filter(w => w)
        if (!words.length)
            return all
        const out = []
        for (const g of all) {
            const items = g.items.filter(i => {
                const hay = (g.name + " " + i.keys + " " + i.what).toLowerCase()
                return words.every(w => hay.includes(w))
            })
            if (items.length)
                out.push({ name: g.name, items: items })
        }
        return out
    }

    function mods(m) {
        const out = []
        if (m & 64) out.push("SUPER")
        if (m & 4) out.push("CTRL")
        if (m & 8) out.push("ALT")
        if (m & 1) out.push("SHIFT")
        return out
    }

    screen: Store.screenFor("cheatsheet")
    visible: Store.isOpen("cheatsheet") || motion.leaving
    onVisibleChanged: {
        if (visible) {
            query = ""
            search.text = ""
            search.forceActiveFocus()
            proc.running = true
        }
    }
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
                root.all = Object.keys(by).map(g => ({ name: g, items: by[g] }))
            }
        }
    }

    Rectangle {
        PanelMotion {
            id: motion
            target: parent
            shown: Store.isOpen("cheatsheet") && !Store.moving
        }
        anchors.fill: parent
        color: Qt.alpha(Theme.crust, 0.75)
        TapHandler { onTapped: Store.setOpen("cheatsheet", false) }

        Rectangle {
            id: box
            anchors.top: parent.top
            anchors.topMargin: 40
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(560, parent.width - 80)
            height: 44
            radius: 22
            color: Qt.alpha(Theme.mantle, 0.95)
            border.width: 1
            border.color: search.activeFocus ? Theme.accent : Theme.surface1

            Text {
                id: glass
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsXl
            }

            TextInput {
                id: search
                anchors.left: glass.right
                anchors.leftMargin: 10
                anchors.right: count.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsLg
                clip: true
                focus: true
                onTextChanged: root.query = text
                Keys.onEscapePressed: Store.setOpen("cheatsheet", false)

                Text {
                    visible: !search.text
                    text: "Search keybinds, e.g. screenshot or super shift"
                    color: Theme.overlay
                    font: search.font
                }
            }

            Text {
                id: count
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.groups.reduce((n, g) => n + g.items.length, 0) + " binds"
                color: Theme.subtext
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSm
            }
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 40
            anchors.topMargin: 104
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
                        spacing: Theme.sp2
                        Text {
                            text: modelData.name
                            color: Theme.accent
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.icon
                            font.weight: Font.DemiBold
                            bottomPadding: 4
                        }
                        Repeater {
                            model: modelData.items
                            Row {
                                required property var modelData
                                spacing: Theme.sp5
                                Text { text: modelData.keys; width: 180; color: Theme.lavender; font.family: Theme.fontMono; font.pixelSize: Theme.fsSm; elide: Text.ElideRight }
                                Text { text: modelData.what; width: 190; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; elide: Text.ElideRight }
                            }
                        }
                    }
                }
            }
        }
    }
}
