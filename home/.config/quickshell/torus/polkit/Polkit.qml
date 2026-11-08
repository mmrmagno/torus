import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs

Scope {
    id: root

    Process {
        running: true
        command: ["systemctl", "--user", "stop", "hyprpolkitagent.service"]
        onExited: loader.active = true
    }

    Process {
        id: fallback
        command: ["systemctl", "--user", "start", "hyprpolkitagent.service"]
    }

    Loader {
        id: loader
        active: false
        sourceComponent: Item {
            PolkitAgent {
                id: agent
            }

            Binding {
                target: Store
                property: "polkitState"
                value: agent.isActive ? "active" : (agent.isRegistered ? "registered" : "none")
            }

            Timer {
                interval: 5000
                running: true
                onTriggered: if (!agent.isRegistered) fallback.running = true
            }

            PanelWindow {
                id: dialog

                readonly property var flow: agent.flow

                screen: Store.focusedScreen
                visible: agent.isActive && flow !== null
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                color: Qt.alpha(Theme.crust, 0.55)
                WlrLayershell.namespace: "torus-polkit"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                onVisibleChanged: if (visible) {
                    password.text = ""
                    password.forceActiveFocus()
                }

                Connections {
                    target: dialog.flow
                    function onIsResponseRequiredChanged() {
                        if (dialog.flow && dialog.flow.isResponseRequired) {
                            password.text = ""
                            password.forceActiveFocus()
                        }
                    }
                }

                function submit() {
                    if (flow && flow.isResponseRequired)
                        flow.submit(password.text)
                    password.text = ""
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 420
                    height: card.implicitHeight + 40
                    radius: 18
                    color: Qt.alpha(Theme.base, Theme.glassCard)
                    border.width: 1
                    border.color: Qt.alpha(Theme.accent, 0.45)

                    ColumnLayout {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 12

                        RowLayout {
                            spacing: 12
                            Text {
                                text: "󰌾"
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: 26
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Authentication required"
                                color: Theme.text
                                font.family: Theme.fontUi
                                font.pixelSize: 17
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: dialog.flow ? dialog.flow.message : ""
                            color: Theme.subtext
                            wrapMode: Text.Wrap
                            font.family: Theme.fontUi
                            font.pixelSize: 13
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: dialog.flow && dialog.flow.actionId ? dialog.flow.actionId : ""
                            color: Theme.overlay
                            elide: Text.ElideMiddle
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 12
                            color: Theme.surface0
                            border.width: 1
                            border.color: dialog.flow && dialog.flow.failed ? Theme.red : Qt.alpha(Theme.accent, password.activeFocus ? 0.7 : 0.2)
                            TextInput {
                                id: password
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: dialog.flow && dialog.flow.responseVisible ? TextInput.Normal : TextInput.Password
                                passwordCharacter: "●"
                                color: Theme.text
                                font.family: Theme.fontUi
                                font.pixelSize: 14
                                enabled: dialog.flow && dialog.flow.isResponseRequired
                                onAccepted: dialog.submit()
                                Keys.onEscapePressed: if (dialog.flow) dialog.flow.cancelAuthenticationRequest()
                                Text {
                                    visible: parent.text === ""
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: dialog.flow && dialog.flow.inputPrompt ? dialog.flow.inputPrompt.replace(/:\s*$/, "") : "Password"
                                    color: Theme.overlay
                                    font: parent.font
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: dialog.flow ? (dialog.flow.failed ? "wrong password, try again" : dialog.flow.supplementaryMessage) : ""
                            color: dialog.flow && (dialog.flow.failed || dialog.flow.supplementaryIsError) ? Theme.red : Theme.subtext
                            wrapMode: Text.Wrap
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: 8
                            Rectangle {
                                implicitWidth: 92
                                implicitHeight: 34
                                radius: 10
                                color: cancelHover.hovered ? Theme.surface1 : Theme.surface0
                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    color: Theme.text
                                    font.family: Theme.fontUi
                                    font.pixelSize: 13
                                }
                                HoverHandler { id: cancelHover }
                                TapHandler { onTapped: if (dialog.flow) dialog.flow.cancelAuthenticationRequest() }
                            }
                            Rectangle {
                                implicitWidth: 120
                                implicitHeight: 34
                                radius: 10
                                color: okHover.hovered ? Theme.lavender : Theme.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: "Authenticate"
                                    color: Theme.crust
                                    font.family: Theme.fontUi
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                                HoverHandler { id: okHover }
                                TapHandler { onTapped: dialog.submit() }
                            }
                        }
                    }
                }
            }
        }
    }
}
