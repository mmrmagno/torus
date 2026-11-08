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

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        IconImage {
            implicitSize: 16
            source: group.entry.icon ? Quickshell.iconPath(group.entry.icon, "dialog-information") : (group.entry.items.length > 0 && group.entry.items[0].image || Quickshell.iconPath("dialog-information"))
        }
        Text {
            Layout.fillWidth: true
            text: group.entry.app
            color: Theme.subtext
            font.family: Theme.fontUi
            font.pixelSize: 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
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
                font.pixelSize: 11
            }
        }
        PanelButton {
            visible: group.entry.items.length >= 3
            icon: group.open ? "󰅃" : "󰅀"
            onClicked: Notifs.toggleGroup(group.entry.app)
        }
        PanelButton {
            icon: "󰎟"
            onClicked: Notifs.clearGroup(group.entry.app)
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
        font.pixelSize: 11
        TapHandler { onTapped: Notifs.toggleGroup(group.entry.app) }
    }
}
