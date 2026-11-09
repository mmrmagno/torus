import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    screen: Store.screenFor("palette")
    visible: Store.isOpen("palette") || motion.leaving
    implicitWidth: 660
    implicitHeight: 520
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) {
        Commands.snapshot()
        search.text = ""
        list.currentIndex = 0
        search.forceActiveFocus()
    }

    Rectangle {
        PanelMotion {
            id: motion
            target: parent
            shown: Store.isOpen("palette")
        }
        anchors.fill: parent
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: Theme.sp5

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 14
                color: Theme.surface0
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.5)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: Theme.sp6
                    Text {
                        text: ({ all: "󰍉", calc: "󰃬", files: "󰈔", kb: "󰈙", ai: "󰚩", emoji: "󰞅", pass: "󰟵", notifs: "󰂚", colors: "󰏘", recent: "󰋚", timer: "󰔛" })[Commands.mode]
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsTitle
                    }
                    TextInput {
                        id: search
                        Connections {
                            target: Commands
                            function onFill(text) {
                                search.text = text
                                search.cursorPosition = text.length
                            }
                        }
                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsXl
                        clip: true
                        onTextChanged: {
                            Commands.query = text
                            list.currentIndex = 0
                        }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape)
                                Store.setOpen("palette", false)
                            else if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)))
                                list.incrementCurrentIndex()
                            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                                list.decrementCurrentIndex()
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                Commands.run(Commands.results[list.currentIndex])
                            else
                                return
                            event.accepted = true
                        }
                        Text {
                            visible: parent.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "apps, windows, actions…"
                            color: Theme.overlay
                            font: parent.font
                        }
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.sp2
                model: Commands.results
                highlightMoveDuration: 100
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 52
                    radius: Theme.rCard
                    color: ListView.isCurrentItem ? Qt.alpha(Theme.accent, 0.18) : (hover.hovered ? Theme.surface0 : "transparent")
                    border.width: ListView.isCurrentItem ? 1 : 0
                    border.color: Qt.alpha(Theme.accent, 0.5)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 14
                        spacing: Theme.sp6

                        Item {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            IconImage {
                                anchors.fill: parent
                                visible: !!row.modelData.icon
                                source: row.modelData.icon || ""
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                visible: !!row.modelData.swatch
                                width: 24
                                height: 24
                                radius: 7
                                color: row.modelData.swatch || "transparent"
                                border.width: 1
                                border.color: Qt.alpha(Theme.text, 0.15)
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !row.modelData.icon && !row.modelData.swatch
                                text: row.modelData.glyph || "󰀻"
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: 20
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.title
                                color: Theme.text
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsLg
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: !!row.modelData.sub
                                text: row.modelData.sub || ""
                                color: Theme.subtext
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsSm
                                elide: Text.ElideMiddle
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: kind.implicitWidth + 14
                            radius: Theme.radius
                            color: Theme.surface1
                            Text {
                                id: kind
                                anchors.centerIn: parent
                                text: row.modelData.kind
                                color: Theme.subtext
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsXs
                            }
                        }
                    }

                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Commands.run(row.modelData) }
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: Commands.mode === "all" ? "nothing matches" : (Commands.term === "" ? "type to search" : "searching…")
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14
                Repeater {
                    model: [["=", "calc"], ["/", "files"], ["r ", "recent"], ["?", "kb"], ["!", "ask AI"], [":", "emoji"], ["#", "colors"], ["t ", "timer"], ["p ", "pass"], ["n ", "notifications"]]
                    Row {
                        required property var modelData
                        spacing: Theme.sp2
                        Rectangle {
                            width: key.implicitWidth + 10
                            height: 18
                            radius: 5
                            color: Theme.surface0
                            Text { id: key; anchors.centerIn: parent; text: parent.parent.modelData[0].trim(); color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsSm }
                        }
                        Text { text: parent.modelData[1]; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
