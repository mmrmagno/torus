import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    screen: Store.focusedScreen
    visible: Store.isOpen("ai")
    anchors {
        top: true
        right: true
        bottom: true
    }
    margins {
        top: Store.barGap
        right: 10
        bottom: 10
    }
    implicitWidth: 460
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) {
        Ai.refresh()
        input.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Qt.alpha(Theme.base, Theme.glass)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: "󰚩"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                }
                Text {
                    Layout.fillWidth: true
                    text: "Local AI"
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                PanelButton {
                    visible: Ai.models.length > 0
                    icon: "󰧑"
                    label: Ai.model
                    onClicked: Ai.cycleModel()
                }
                PanelButton { icon: "󰐕"; onClicked: Ai.reset() }
                PanelButton { icon: "󰅖"; onClicked: Store.setOpen("ai", false) }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: hint.implicitHeight + 28
                visible: Ai.status === "offline" || (Ai.status === "online" && Ai.models.length === 0)
                radius: 12
                color: Theme.surface0
                Column {
                    id: hint
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6
                    Text {
                        text: Ai.status === "offline" ? "Ollama is not running" : "No models yet"
                        color: Theme.peach
                        font.family: Theme.fontUi
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: Ai.status === "offline" ? "Start it, then reopen this panel:" : "Pull one, then reopen this panel:"
                        color: Theme.subtext
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                    }
                    Text {
                        text: Ai.status === "offline" ? "systemctl enable --now ollama" : "ollama pull llama3.2"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                    }
                }
            }

            ListView {
                id: chat
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 10
                model: Ai.messages
                onCountChanged: positionViewAtEnd()
                delegate: Item {
                    id: msg
                    required property var modelData
                    required property int index
                    readonly property bool mine: modelData.role === "user"
                    width: ListView.view.width
                    height: bubble.height
                    onHeightChanged: if (index === chat.count - 1) chat.positionViewAtEnd()

                    Rectangle {
                        id: bubble
                        anchors.right: msg.mine ? parent.right : undefined
                        anchors.left: msg.mine ? undefined : parent.left
                        width: Math.min(parent.width * (msg.mine ? 0.85 : 1), body.implicitWidth + 28)
                        height: body.implicitHeight + (msg.mine ? 20 : 40)
                        radius: 12
                        color: msg.mine ? Qt.alpha(Theme.accent, 0.2) : Qt.alpha(Theme.surface0, 0.8)
                        TextEdit {
                            id: body
                            x: 14
                            y: 10
                            width: (msg.mine ? chat.width * 0.85 : chat.width) - 28
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.PlainText
                            text: msg.modelData.content || (Ai.busy ? "…" : "")
                            color: Theme.text
                            selectionColor: Qt.alpha(Theme.accent, 0.4)
                            font.family: Theme.fontUi
                            font.pixelSize: 13
                        }
                        Text {
                            visible: !msg.mine && msg.modelData.content !== ""
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            text: copied.running ? "󰄬 copied" : "󰆏 copy"
                            color: copyHover.hovered ? Theme.lavender : Theme.overlay
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            HoverHandler { id: copyHover }
                            TapHandler {
                                onTapped: {
                                    Quickshell.execDetached(["wl-copy", "--", msg.modelData.content])
                                    copied.restart()
                                }
                            }
                            Timer { id: copied; interval: 1200 }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    visible: chat.count === 0 && Ai.status === "online" && Ai.models.length > 0
                    text: "Ask " + Ai.model + " anything. Runs on this machine, nothing leaves it."
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                }
            }

            Text {
                Layout.fillWidth: true
                visible: Ai.error !== ""
                text: Ai.error
                color: Theme.red
                font.family: Theme.fontUi
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(140, input.implicitHeight + 20)
                radius: 12
                color: Theme.surface0
                border.width: input.activeFocus ? 1 : 0
                border.color: Qt.alpha(Theme.accent, 0.6)
                TextEdit {
                    id: input
                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.rightMargin: 40
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    enabled: Ai.status === "online" && Ai.models.length > 0
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            Store.setOpen("ai", false)
                            event.accepted = true
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                            Ai.ask(text)
                            if (Ai.busy)
                                text = ""
                            event.accepted = true
                        }
                    }
                    Text {
                        visible: parent.text === ""
                        text: Ai.busy ? "thinking…" : "message, shift+enter for a new line"
                        color: Theme.overlay
                        font: parent.font
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: Ai.busy ? "󰓛" : "󰒊"
                    color: Ai.busy ? Theme.red : Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 16
                    TapHandler {
                        onTapped: {
                            if (Ai.busy) {
                                Ai.stop()
                            } else {
                                Ai.ask(input.text)
                                if (Ai.busy)
                                    input.text = ""
                            }
                        }
                    }
                }
            }
        }
    }
}
