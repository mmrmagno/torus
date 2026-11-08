import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

import Quickshell.Hyprland
import Quickshell.Widgets

Row {
    id: root
    property bool available: true
    readonly property bool shown: windows.count > 0
    property var monitor: QsWindow.window ? Hyprland.monitorFor(QsWindow.window.screen) : null
    spacing: 8

    Repeater {
        id: windows
        model: Hyprland.toplevels.values.filter(t => t.workspace && root.monitor && t.workspace === root.monitor.activeWorkspace)

        IconImage {
            required property var modelData
            readonly property string appId: modelData.wayland && modelData.wayland.appId ? modelData.wayland.appId : (modelData.lastIpcObject ? modelData.lastIpcObject.class || "" : "")
            readonly property var entry: DesktopEntries.applications.values.length >= 0 ? DesktopEntries.heuristicLookup(appId) : null
            implicitSize: 16
            anchors.verticalCenter: parent.verticalCenter
            source: Quickshell.iconPath(entry ? entry.icon : "", "application-x-executable")
            opacity: modelData.activated ? 1 : 0.55

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.modelData.wayland ? parent.modelData.wayland.activate() : null
            }
        }
    }
}
