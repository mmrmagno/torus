import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs
import qs.services

PanelWindow {
    id: root

    property string icon: ""
    property string label: ""
    property real value: -1
    property bool armed: false

    function show(i, l, v) {
        if (!armed)
            return
        icon = i
        label = l
        value = v
        Store.osdVisible = true
        hide.restart()
    }

    screen: Store.focusedScreen
    visible: Store.osdVisible
    anchors.bottom: true
    margins.bottom: 80
    implicitWidth: 300
    implicitHeight: 56
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    Timer { id: hide; interval: 1500; onTriggered: Store.osdVisible = false }
    Timer { interval: 2000; running: true; onTriggered: root.armed = true }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() { const a = Pipewire.defaultAudioSink.audio; root.show(a.muted ? "󰝟" : "󰕾", Math.round(a.volume * 100) + "%", a.volume) }
        function onMutedChanged() { const a = Pipewire.defaultAudioSink.audio; root.show(a.muted ? "󰝟" : "󰕾", a.muted ? "muted" : Math.round(a.volume * 100) + "%", a.muted ? 0 : a.volume) }
    }

    Connections {
        target: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
        function onMutedChanged() { const a = Pipewire.defaultAudioSource.audio; root.show(a.muted ? "󰍭" : "󰍬", a.muted ? "mic muted" : "mic on", -1) }
    }

    Connections {
        target: Backlight
        function onPercentChanged() { root.show("󰃟", Backlight.percent + "%", Backlight.percent / 100) }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                root.show("󰌌", event.data.split(",").slice(1).join(","), -1)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.alpha(Theme.base, 0.92)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.4)

        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Text {
                text: root.icon
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: 22
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                visible: root.value >= 0
                width: 170
                height: 8
                radius: 4
                color: Theme.surface0
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: parent.width * Math.min(1, Math.max(0, root.value))
                    height: parent.height
                    radius: 4
                    color: root.value > 1 ? Theme.peach : Theme.accent
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }

            Text {
                text: root.label
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
