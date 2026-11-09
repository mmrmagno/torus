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

    screen: Store.focusedScreen
    visible: Store.isOpen("palette")
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
            target: parent
            shown: root.visible
        }
        anchors.fill: parent
        radius: 18
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

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
                    spacing: 12
                    Text {
                        text: ({ all: "󰍉", calc: "󰃬", files: "󰈔", kb: "󰈙", ai: "󰚩", emoji: "󰞅", pass: "󰟵" })[Commands.mode]
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 18
                    }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: 16
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
                spacing: 4
                model: Commands.results
                highlightMoveDuration: 100
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 52
                    radius: 12
                    color: ListView.isCurrentItem ? Qt.alpha(Theme.accent, 0.18) : (hover.hovered ? Theme.surface0 : "transparent")
                    border.width: ListView.isCurrentItem ? 1 : 0
                    border.color: Qt.alpha(Theme.accent, 0.5)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 14
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            IconImage {
                                anchors.fill: parent
                                visible: !!row.modelData.icon
                                source: row.modelData.icon || ""
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !row.modelData.icon
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
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: !!row.modelData.sub
                                text: row.modelData.sub || ""
                                color: Theme.subtext
                                font.family: Theme.fontUi
                                font.pixelSize: 11
                                elide: Text.ElideMiddle
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: kind.implicitWidth + 14
                            radius: 10
                            color: Theme.surface1
                            Text {
                                id: kind
                                anchors.centerIn: parent
                                text: row.modelData.kind
                                color: Theme.subtext
                                font.family: Theme.fontUi
                                font.pixelSize: 10
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
                    font.pixelSize: 13
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14
                Repeater {
                    model: [["=", "calc"], ["/", "files"], ["?", "kb"], ["!", "ask AI"], [":", "emoji"], ["p ", "pass"]]
                    Row {
                        required property var modelData
                        spacing: 4
                        Rectangle {
                            width: key.implicitWidth + 10
                            height: 18
                            radius: 5
                            color: Theme.surface0
                            Text { id: key; anchors.centerIn: parent; text: parent.parent.modelData[0].trim(); color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 11 }
                        }
                        Text { text: parent.modelData[1]; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
