import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    screen: Store.screenFor("center")
    visible: Store.isOpen("center") || motion.leaving
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
    implicitWidth: 420
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property bool clearing: false

    function clearAll() {
        if (clearing || Notifs.count === 0)
            return
        clearing = true
        clearTimer.interval = Theme.durMed + Math.min(Notifs.groups.length, 12) * 45 + 40
        clearTimer.restart()
    }

    Timer {
        id: clearTimer
        onTriggered: {
            Notifs.clearAll()
            root.clearing = false
        }
    }

    onVisibleChanged: if (!visible) {
        search.text = ""
        Notifs.filter = ""
    }

    component LiveCard: Rectangle {
        id: live
        property string glyph
        property string title
        property string value
        property real progress: -1
        property color tint: Theme.accent
        property var buttons: []
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Theme.radius
        color: Qt.alpha(Theme.surface0, 0.7)
        border.width: 1
        border.color: Qt.alpha(live.tint, 0.4)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: Theme.sp5
            Text { text: live.glyph; color: live.tint; font.family: Theme.fontMono; font.pixelSize: 20 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: live.title; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: live.value; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsXl; font.weight: Font.DemiBold }
            }
            Repeater {
                model: live.buttons
                PanelButton {
                    required property var modelData
                    icon: modelData[0]
                    implicitHeight: 30
                    onClicked: modelData[1]()
                }
            }
        }
        Rectangle {
            visible: live.progress >= 0
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: 2
            radius: 1
            width: (parent.width - 2) * Math.max(0, Math.min(1, live.progress))
            color: live.tint
        }
    }

    Rectangle {
        PanelMotion {
            id: motion
            target: parent
            shown: Store.isOpen("center") && !Store.moving
        }
        anchors.fill: parent
        radius: 14
        color: Qt.alpha(Theme.base, Theme.glass)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        focus: true
        Keys.onEscapePressed: Store.setOpen("center", false)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: Theme.sp6

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp4
                Text {
                    text: "Notifications"
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsTitle
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    visible: Notifs.count > 0
                    implicitWidth: totalText.implicitWidth + 14
                    implicitHeight: 20
                    radius: 10
                    color: Qt.alpha(Theme.accent, 0.2)
                    Text { id: totalText; anchors.centerIn: parent; text: Notifs.count; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsSm; font.weight: Font.Bold }
                }
                Item { Layout.fillWidth: true }
                PanelButton { icon: Store.dnd ? "󰂛" : "󰂚"; label: Store.dnd ? "Silent" : ""; active: Store.dnd; implicitHeight: 30; onClicked: Store.dnd = !Store.dnd }
                PanelButton { icon: "󰎟"; label: "Clear all"; visible: Notifs.count > 0; implicitHeight: 30; onClicked: root.clearAll() }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 17
                color: Theme.surface0
                border.width: search.activeFocus ? 1 : 0
                border.color: Theme.accent
                Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; color: Theme.overlay; font.family: Theme.fontMono; font.pixelSize: Theme.icon }
                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 36
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                    clip: true
                    onTextChanged: Notifs.filter = text
                    Keys.onEscapePressed: text !== "" ? text = "" : Store.setOpen("center", false)
                    Text {
                        visible: parent.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search notifications"
                        color: Theme.overlay
                        font: parent.font
                    }
                }
            }

            Rectangle {
                readonly property int fresh: Notifs.list.filter(n => (Notifs.arrived[n.id] || 0) >= Notifs.lastAway).length
                visible: Notifs.lastAway > 0 && fresh > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: Theme.radius
                color: Qt.alpha(Theme.accent, 0.12)
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.4)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    Text { text: "󰂞"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.icon }
                    Text {
                        Layout.fillWidth: true
                        text: "While you were away (since " + Qt.formatTime(new Date(Notifs.lastAway), "HH:mm") + "): " + parent.parent.fresh + " new"
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsMd
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "󰅖"
                        color: Theme.overlay
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsLg
                        TapHandler { onTapped: Notifs.lastAway = 0 }
                    }
                }
            }

            MediaCard { Layout.fillWidth: true }

            LiveCard {
                visible: Timers.running
                glyph: Timers.stopwatch ? "󱎫" : "󰔛"
                title: (Timers.stopwatch ? "Stopwatch" : "Timer") + (Timers.label ? "  ·  " + Timers.label : "")
                value: Timers.text + (Timers.paused ? "  paused" : "")
                progress: Timers.stopwatch ? -1 : Timers.progress
                tint: Theme.peach
                buttons: [[Timers.paused ? "󰐊" : "󰏤", () => Timers.togglePause()], ["󰓛", () => Timers.stop()]]
            }

            LiveCard {
                visible: Focus.running
                glyph: "󰔟"
                title: "Focus  ·  notifications held"
                value: String(Math.floor(Focus.left / 60)).padStart(2, "0") + ":" + String(Focus.left % 60).padStart(2, "0")
                progress: Focus.progress
                tint: Theme.accent
                buttons: [["󰓛", () => Focus.stop()]]
            }

            Flow {
                Layout.fillWidth: true
                spacing: Theme.sp3
                PanelButton { icon: "󰖩"; label: "Network"; onClicked: { Store.setOpen("center", false); Store.setOpen("network", true) } }
                PanelButton { icon: "󰖔"; label: "Night light"; active: NightLight.on; onClicked: NightLight.toggle() }
                PanelButton { icon: "󰔛"; label: "Timer"; onClicked: { Store.setOpen("center", false); Store.setOpen("palette", true); Commands.fill("t ") } }
                PanelButton { icon: "󰐥"; label: "Session"; onClicked: { Store.setOpen("center", false); Store.setOpen("logout", true) } }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.sp4
                model: ScriptModel { values: Notifs.groups.map(g => g.app) }
                delegate: NotifGroup {
                    required property var modelData
                    required property int index
                    app: modelData
                    order: index
                    leaving: root.clearing
                    width: ListView.view.width
                }
                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMed }
                        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.durMed; easing.type: Easing.OutCubic }
                    }
                }
                displaced: Transition {
                    NumberAnimation { property: "y"; duration: Theme.durMed; easing.type: Easing.OutCubic }
                }
                Text {
                    anchors.centerIn: list
                    visible: list.count === 0
                    text: Notifs.filter !== "" ? "nothing matches" : "󰂜  all caught up"
                    color: Theme.overlay
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsLg
                }
            }
        }
    }
}
