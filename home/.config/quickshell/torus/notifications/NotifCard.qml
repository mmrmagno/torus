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

    readonly property bool fresh: notif && Notifs.lastAway > 0 && (Notifs.arrived[notif.id] || 0) >= Notifs.lastAway
    property real swipe: 0
    transform: Translate { x: card.swipe }
    opacity: 1 - Math.min(0.8, Math.abs(swipe) / width)
    Behavior on swipe { enabled: !drag.active; NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }

    DragHandler {
        id: drag
        enabled: !card.popup
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onTranslationChanged: if (active) card.swipe = translation.x
        onActiveChanged: {
            if (active)
                return
            if (Math.abs(card.swipe) > card.width * 0.35) {
                card.swipe = card.swipe > 0 ? card.width * 1.2 : -card.width * 1.2
                gone.start()
            } else {
                card.swipe = 0
            }
        }
    }

    Timer {
        id: gone
        interval: Theme.durMed
        onTriggered: if (card.notif) card.notif.dismiss()
    }

    Rectangle {
        visible: card.fresh
        x: 6
        y: 8
        width: 6
        height: 6
        radius: 3
        color: Theme.accent
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 12
        spacing: Theme.sp6

        NotifIcon {
            Layout.alignment: Qt.AlignTop
            size: 40
            image: card.notif ? card.notif.image || "" : ""
            appIcon: card.notif ? card.notif.appIcon || "" : ""
            app: card.notif ? card.notif.appName || "" : ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: card.notif ? card.notif.summary : ""
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsLg
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Rectangle {
                    readonly property int times: card.notif ? (Notifs.repeats[card.notif.id] || 1) : 1
                    visible: times > 1
                    width: timesText.implicitWidth + 12
                    height: 18
                    radius: 9
                    color: Qt.alpha(Theme.accent, 0.2)
                    Text { id: timesText; anchors.centerIn: parent; text: "×" + parent.times; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs; font.weight: Font.Bold }
                }
                Text {
                    property int tick: 0
                    text: card.notif ? (card.popup ? card.notif.appName : Notifs.ago(card.notif) + (tick < 0 ? "" : "")) : ""
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSm
                    Timer {
                        running: !card.popup && card.visible
                        interval: 30000
                        repeat: true
                        onTriggered: parent.tick++
                    }
                }
                Text {
                    text: "󰅖"
                    color: closeHover.hovered ? Theme.red : Theme.overlay
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsLg
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
                font.pixelSize: Theme.fsMd
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 4 : 8
                elide: Text.ElideRight
                textFormat: Text.StyledText
            }

            Row {
                spacing: Theme.sp3
                visible: card.notif && card.notif.actions.length > 0
                Repeater {
                    model: card.notif ? card.notif.actions : []
                    Rectangle {
                        required property var modelData
                        width: actionText.implicitWidth + 16
                        height: 24
                        radius: Theme.rSm
                        color: actionHover.hovered ? Theme.surface1 : Theme.surface0
                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            color: Theme.text
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsMd
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
                radius: Theme.rSm
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
                    font.pixelSize: Theme.fsMd
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
                    font.pixelSize: Theme.fsLg
                    TapHandler { onTapped: reply.send() }
                }
            }
        }
    }
}
