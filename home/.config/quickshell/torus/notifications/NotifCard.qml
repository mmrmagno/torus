import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.components
import qs.services

Item {
    id: card

    required property var notif
    property var earlier: []

    function dismissAll() {
        for (const e of earlier.slice())
            e.dismiss()
        if (notif)
            notif.dismiss()
    }
    property bool popup: false
    readonly property var actions: notif ? notif.actions.filter(a => a.identifier !== "default" && a.text.trim() !== "") : []
    readonly property var defaultAction: notif ? notif.actions.find(a => a.identifier === "default") : null
    readonly property string body: notif ? notif.body.replace(/<img\b[^>]*>/gi, "").trim() : ""
    readonly property bool hasBody: body.replace(/<[^>]*>/g, "").replace(/&nbsp;|&#160;/gi, " ").trim() !== ""
    signal done

    Component.onCompleted: {
        Store.cardsMade++
        focusReply()
    }
    implicitWidth: 380
    implicitHeight: layout.implicitHeight + 24

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
    Behavior on swipe { enabled: !drag.active && !wheelReset.running; NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }

    function activate() {
        const action = defaultAction
        if (!action)
            return
        action.invoke()
        if (!popup)
            Store.setOpen("center", false)
        done()
    }

    function focusReply() {
        if (!popup && notif && notif.hasInlineReply && Notifs.replyTarget === notif.id) {
            Notifs.replyTarget = -1
            Qt.callLater(() => reply.forceActiveFocus())
        }
    }
    Connections {
        target: Notifs
        enabled: !card.popup
        function onReplyTargetChanged() { card.focusReply() }
    }

    function finishSwipe() {
        if (gone.running)
            return
        if (Math.abs(swipe) > width * 0.30) {
            swipe = swipe > 0 ? width * 1.2 : -width * 1.2
            gone.start()
        } else {
            swipe = 0
        }
    }

    // Touchpads send two-finger scrolling as wheel events, not pointer drags.
    // A WheelHandler keeps diagonal touchpad scrolls from the centre list, a MouseArea passes them on.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            const flip = event.inverted ? -1 : 1
            const dx = flip * (event.pixelDelta.x || event.angleDelta.x / 2)
            const dy = event.pixelDelta.y || event.angleDelta.y / 2
            if (gone.running || dx === 0 || (!wheelReset.running && Math.abs(dx) <= 2 * Math.abs(dy))) {
                event.accepted = false
                return
            }
            wheelReset.restart()
            card.swipe = Math.max(-card.width, Math.min(card.width, card.swipe + dx))
            if (Math.abs(card.swipe) > card.width * 0.30) {
                wheelReset.stop()
                card.finishSwipe()
            }
        }
    }
    Timer { id: wheelReset; interval: 180; onTriggered: card.finishSwipe() }

    DragHandler {
        id: drag
        enabled: !gone.running
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onTranslationChanged: if (active) card.swipe = translation.x
        onActiveChanged: {
            if (active)
                return
            card.finishSwipe()
        }
    }

    Timer {
        id: gone
        interval: Theme.durMed
        onTriggered: {
            if (card.popup)
                card.done()
            else if (card.notif)
                card.dismissAll()
        }
    }

    // Move only the visual, keeping the wheel hit area under a stationary pointer.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: card.notif && card.notif.urgency === NotificationUrgency.Critical ? 2 : 1
        border.color: card.notif && card.notif.urgency === NotificationUrgency.Critical ? Theme.red : Qt.alpha(Theme.accent, 0.5)
        transform: Translate { x: card.swipe }
        opacity: 1 - Math.min(0.8, Math.abs(card.swipe) / width)

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
                TapHandler { enabled: !!card.defaultAction; onTapped: card.activate() }
                HoverHandler { enabled: !!card.defaultAction; cursorShape: Qt.PointingHandCursor }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: card.notif ? card.notif.summary : ""
                        TapHandler { enabled: !!card.defaultAction; onTapped: card.activate() }
                        HoverHandler { enabled: !!card.defaultAction; cursorShape: Qt.PointingHandCursor }
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
                        TapHandler { onTapped: card.popup ? card.notif.dismiss() : card.dismissAll() }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: card.hasBody
                    text: card.body
                    TapHandler { enabled: !!card.defaultAction; onTapped: card.activate() }
                    HoverHandler { enabled: !!card.defaultAction; cursorShape: Qt.PointingHandCursor }
                    color: Theme.subtext
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                    wrapMode: Text.Wrap
                    maximumLineCount: card.popup ? 4 : 8
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                }

                Repeater {
                    model: card.popup ? [] : card.earlier.slice(0, 3)
                    Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: "· " + modelData.body.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim()
                        color: Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSm
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
                Text {
                    visible: !card.popup && card.earlier.length > 3
                    text: "and " + (card.earlier.length - 3) + " earlier"
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsXs
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.sp3
                    visible: card.actions.length > 0
                    Repeater {
                        model: card.actions
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
                    visible: !card.popup && card.notif && card.notif.hasInlineReply
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

                PanelButton {
                    visible: card.popup && card.notif && card.notif.hasInlineReply
                    label: "Reply in notification centre"
                    onClicked: Notifs.openReply(card.notif)
                }
            }
        }
    }
}
