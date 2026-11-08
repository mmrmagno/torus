import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: root

    readonly property bool donutMode: Store.wallpaper === "donut"
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

    Image {
        anchors.fill: parent
        visible: !root.donutMode
        source: root.donutMode ? "" : "file://" + Store.wallpaper.slice(6)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.width
        sourceSize.height: root.height
    }
}
