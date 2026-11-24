import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs

PanelWindow {
    id: root

    required property var lock

    onBackingWindowVisibleChanged: if (backingWindowVisible) Store.dissolves++
    visible: lock.dissolving && pic.status === Image.Ready
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "torus-fly"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
        anchors.fill: parent
        opacity: root.lock.dissolve

        Image {
            id: pic
            anchors.fill: parent
            visible: false
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            source: Store.locked || root.lock.dissolving ? root.lock.shotUrl(root.screen) : ""
        }
        MultiEffect {
            anchors.fill: parent
            source: pic
            blurEnabled: true
            blur: 1
            blurMax: 64
            brightness: -0.18
            saturation: -0.2
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Theme.crust, 0.45) }
                GradientStop { position: 1; color: Qt.alpha(Theme.base, 0.7) }
            }
        }
    }
}
