import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.components
import qs.services

Rectangle {
    id: card

    required property var notif
    property bool popup: false
    signal done

    Component.onCompleted: Store.cardsMade++
    implicitWidth: 380
    implicitHeight: layout.implicitHeight + 24
    radius: Theme.radius
    color: Qt.alpha(Theme.base, Theme.glassCard)
    border.width: notif && notif.urgency === NotificationUrgency.Critical ? 2 : 1
    border.color: notif && notif.urgency === NotificationUrgency.Critical ? Theme.red : Qt.alpha(Theme.accent, 0.5)

    Timer {
        running: card.popup && hover.hovered
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: Notifs.hold(card.notif)
    }

    HoverHandler { id: hover }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        NotifIcon {
            Layout.alignment: Qt.AlignTop
            size: 40
            image: card.notif ? card.notif.image || "" : ""
            appIcon: card.notif ? card.notif.appIcon || "" : ""
            app: card.notif ? card.notif.appName || "" : ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: card.notif ? card.notif.summary : ""
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    text: card.notif ? card.notif.appName : ""
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                }
                Text {
                    text: "󰅖"
                    color: closeHover.hovered ? Theme.red : Theme.overlay
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: card.notif.dismiss() }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notif ? card.notif.body.replace(/<img\b[^>]*>/gi, "") : ""
                color: Theme.subtext
                font.family: Theme.fontUi
                font.pixelSize: 12
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 4 : 8
                elide: Text.ElideRight
                textFormat: Text.StyledText
            }

            Row {
                spacing: 6
                visible: card.notif && card.notif.actions.length > 0
                Repeater {
                    model: card.notif ? card.notif.actions : []
                    Rectangle {
                        required property var modelData
                        width: actionText.implicitWidth + 16
                        height: 24
                        radius: 8
                        color: actionHover.hovered ? Theme.surface1 : Theme.surface0
                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            color: Theme.text
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                        }
                        HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: parent.modelData.invoke() }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                visible: card.notif && card.notif.hasInlineReply
                radius: 8
                color: Theme.surface0
                border.width: reply.activeFocus ? 1 : 0
                border.color: Theme.accent
                TextInput {
                    id: reply
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 34
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    clip: true
                    onAccepted: send()
                    function send() {
                        if (text === "")
                            return
                        card.notif.sendInlineReply(text)
                        text = ""
                        card.done()
                    }
                    Text {
                        visible: parent.text === "" && !parent.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.notif && card.notif.inlineReplyPlaceholder ? card.notif.inlineReplyPlaceholder : "Reply"
                        color: Theme.overlay
                        font: parent.font
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰒊"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    TapHandler { onTapped: reply.send() }
                }
            }
        }
    }
}
