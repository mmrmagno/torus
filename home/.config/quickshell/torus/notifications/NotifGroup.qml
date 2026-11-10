import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services

ColumnLayout {
    id: group

    required property string app
    readonly property var entry: Notifs.groups.find(g => g.app === app) || ({ app: app, icon: "", items: [] })
    readonly property bool open: entry.items.length < 3 || Notifs.expanded[entry.app] === true
    readonly property bool muted: Notifs.muted[app] > Date.now()
    property bool muteMenu: false
    property bool leaving: false
    property int order: 0

    spacing: Theme.sp3
    transform: Translate { id: slide; x: 0 }
    SequentialAnimation {
        running: group.leaving
        PauseAnimation { duration: Math.max(0, group.order) * 45 }
        ParallelAnimation {
            NumberAnimation { target: slide; property: "x"; to: group.width; duration: Theme.durMed; easing.type: Easing.InCubic }
            NumberAnimation { target: group; property: "opacity"; to: 0; duration: Theme.durMed }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp4
        NotifIcon {
            size: 16
            appIcon: group.entry.icon || ""
            app: group.entry.app
        }
        Text {
            Layout.fillWidth: true
            text: group.entry.app
            color: Theme.subtext
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsMd
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            visible: group.muted
            text: "󰂛 until " + Qt.formatTime(new Date(Notifs.muted[group.app] || 0), "HH:mm")
            color: Theme.peach
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsXs
        }
        Rectangle {
            visible: group.entry.items.length > 1
            implicitWidth: countText.implicitWidth + 12
            implicitHeight: 18
            radius: 9
            color: Qt.alpha(Theme.accent, 0.2)
            Text {
                id: countText
                anchors.centerIn: parent
                text: group.entry.items.length
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsSm
            }
        }
        PanelButton {
            visible: group.entry.items.length >= 3
            icon: group.open ? "󰅃" : "󰅀"
            onClicked: Notifs.toggleGroup(group.entry.app)
        }
        PanelButton {
            icon: group.muted ? "󰂛" : "󰂚"
            active: group.muted || group.muteMenu
            implicitHeight: 28
            onClicked: group.muteMenu = !group.muteMenu
        }
        PanelButton {
            icon: "󰎟"
            implicitHeight: 28
            onClicked: Notifs.clearGroup(group.entry.app)
        }
    }

    Flow {
        visible: group.muteMenu
        Layout.fillWidth: true
        spacing: Theme.sp3
        Repeater {
            model: group.muted ? [["Unmute", 0]] : [["Mute 1 hour", 60], ["Mute until tomorrow", -1], ["Mute 8 hours", 480]]
            Rectangle {
                required property var modelData
                width: muteText.implicitWidth + 20
                height: 26
                radius: 13
                color: muteHover.hovered ? Theme.accent : Theme.surface0
                Text { id: muteText; anchors.centerIn: parent; text: parent.modelData[0]; color: muteHover.hovered ? Theme.crust : Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                HoverHandler { id: muteHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        const m = parent.modelData[1]
                        Notifs.mute(group.app, m < 0 ? Notifs.untilTomorrow() : m)
                        group.muteMenu = false
                    }
                }
            }
        }
    }

    Repeater {
        model: ScriptModel { values: group.open ? group.entry.items : group.entry.items.slice(0, 1) }
        NotifCard {
            required property var modelData
            notif: modelData
            Layout.fillWidth: true
        }
    }

    Text {
        visible: !group.open
        Layout.leftMargin: 4
        text: "+" + (group.entry.items.length - 1) + " more"
        color: Theme.overlay
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSm
        TapHandler { onTapped: Notifs.toggleGroup(group.entry.app) }
    }
}
