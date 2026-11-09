import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick.Effects
import qs
import qs.services

PanelWindow {
    id: root

    readonly property string mode: Store.wallFor(screen ? screen.name : "")
    readonly property bool donutMode: mode === "donut" || mode === "xwing"
    readonly property real cellH: Math.round(Math.min(width, height) * 0.5 / DonutClock.h)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: Theme.base
    WlrLayershell.namespace: "torus-bg"
    WlrLayershell.layer: WlrLayer.Background

    Rectangle {
        anchors.fill: parent
        visible: root.donutMode
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.base }
            GradientStop { position: 1; color: Theme.mantle }
        }
    }

    Text {
        visible: root.donutMode
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.cellH * DonutClock.h / 2 + root.cellH * 1.4
        text: "<font color=\"" + Theme.mauve + "\">marc</font><font color=\"" + Theme.overlay + "\"> @ </font><font color=\"" + Theme.lavender + "\">os</font>"
        textFormat: Text.RichText
        font.family: Theme.fontMono
        font.pixelSize: Math.max(12, root.cellH * 0.8)
        opacity: 0.55
    }

    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property bool empty: monitor && monitor.activeWorkspace ? !Hyprland.toplevels.values.some(t => t.workspace === monitor.activeWorkspace) : false
    readonly property bool breathe: Store.breathing && !donutMode && empty && Theme.motion > 0

    Image {
        id: picture
        anchors.fill: parent
        visible: !root.donutMode && !root.breathe
        source: root.donutMode ? "" : "file://" + root.mode.slice(6)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.width
        sourceSize.height: root.height
    }

    MultiEffect {
        id: breath
        anchors.fill: parent
        visible: root.breathe
        source: picture
        blurEnabled: true
        blurMax: 48
        property real phase: 0
        blur: 0.18 + 0.17 * Math.sin(phase)
        scale: 1.015 + 0.015 * Math.sin(phase)
        NumberAnimation on phase { running: root.breathe; from: 0; to: 2 * Math.PI; duration: 16000; loops: Animation.Infinite }
    }
}
