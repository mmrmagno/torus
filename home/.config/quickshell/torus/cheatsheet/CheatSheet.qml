import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import "keys.mjs" as K

PanelWindow {
    id: root

    property var all: []
    readonly property var panelKeys: ({ name: "In panels", items: [
        { keys: ["Tab", "Shift Tab"], what: "move between buttons, switches and sliders", hay: "in panels tab shift move between buttons switches sliders" },
        { keys: ["↵", "Space"], what: "press the focused button or flip the switch", hay: "in panels enter space press button flip switch" },
        { keys: ["←", "→"], what: "move a slider or a segmented choice", hay: "in panels left right slider segmented" },
        { keys: ["↑", "↓"], what: "move through lists (palette, clipboard, games)", hay: "in panels up down lists palette clipboard games" },
        { keys: ["Esc"], what: "close the panel", hay: "in panels esc escape close" }
    ] })
    property string query: ""
    readonly property var groups: K.filter(all, query)

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
    WlrLayershell.keyboardFocus: Store.isOpen("cheatsheet") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Process {
        id: proc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.all = K.groups(JSON.parse(text), [root.panelKeys])
                } catch (e) {
                    root.all = [root.panelKeys]
                }
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
                        spacing: Theme.sp3
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
                                id: bindRow
                                required property var modelData
                                spacing: Theme.sp5
                                Flow {
                                    width: 176
                                    spacing: Theme.sp1
                                    Repeater {
                                        model: bindRow.modelData.keys
                                        Keycap {
                                            required property string modelData
                                            text: modelData
                                        }
                                    }
                                }
                                Text {
                                    text: bindRow.modelData.what
                                    width: 190
                                    color: Theme.text
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsSm
                                    wrapMode: Text.WordWrap
                                    topPadding: 2
                                }
                            }
                        }
                    }
                }
            }
        }

        HintPill {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            hints: [["type", "search"], ["Esc", "close"]]
        }
    }
}
