import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    property string asking: ""
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices.values.slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name || "").localeCompare(b.name || "")) : []

    Connections {
        target: Wifi
        function onFailedSsidChanged() {
            const n = Wifi.networks.find(x => x.ssid === Wifi.failedSsid)
            if (n && n.secure && root.visible)
                root.asking = n.ssid
        }
    }

    function bars(s) {
        return s >= 75 ? "󰤨" : s >= 50 ? "󰤥" : s >= 25 ? "󰤢" : "󰤟"
    }

    screen: Store.focusedScreen
    visible: Store.isOpen("network")
    onVisibleChanged: {
        if (visible) {
            asking = ""
            Wifi.refresh(false)
        } else if (adapter && adapter.discovering) {
            adapter.discovering = false
        }
    }
    anchors {
        top: true
        right: true
    }
    margins {
        top: Store.barGap
        right: 10
    }
    implicitWidth: 380
    implicitHeight: Math.min(720, body.implicitHeight + 32)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.asking !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    component Toggle: Rectangle {
        id: tg
        property bool on: false
        signal toggled
        width: 38
        height: 22
        radius: 11
        color: on ? Theme.accent : Theme.surface1
        Behavior on color { ColorAnimation { duration: 140 } }
        Rectangle {
            x: tg.on ? tg.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 8
            color: tg.on ? Theme.crust : Theme.text
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: tg.toggled() }
    }

    component Heading: RowLayout {
        id: hd
        property string glyph: ""
        property string title: ""
        default property alias extra: tail.data
        Layout.fillWidth: true
        spacing: 8
        Text { text: hd.glyph; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 16 }
        Text { text: hd.title; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true }
        Row { id: tail; spacing: 8 }
    }

    component SmallButton: Rectangle {
        id: sb
        property string label: ""
        property bool danger: false
        signal clicked
        width: sbText.implicitWidth + 20
        height: 24
        radius: 12
        color: sbHover.hovered ? (danger ? Theme.red : Theme.accent) : Theme.surface1
        Behavior on color { ColorAnimation { duration: 120 } }
        Text { id: sbText; anchors.centerIn: parent; text: sb.label; color: sbHover.hovered ? Theme.crust : Theme.text; font.family: Theme.fontUi; font.pixelSize: 11 }
        HoverHandler { id: sbHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: sb.clicked() }
    }

    Rectangle {
        PanelMotion {
            target: parent
            shown: root.visible
        }
        anchors.fill: parent
        radius: 18
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: 16
            contentHeight: body.implicitHeight
            clip: true

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    visible: Wifi.wired !== ""
                    spacing: 8
                    Text { text: "󰈀"; color: Theme.green; font.family: Theme.fontMono; font.pixelSize: 16 }
                    Text { text: "Wired · " + Wifi.wired + " connected"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: 12; Layout.fillWidth: true }
                }

                Heading {
                    glyph: "󰖩"
                    title: "Wi-Fi"
                    SmallButton { label: Wifi.scanning ? "scanning…" : "rescan"; visible: Wifi.enabled; onClicked: Wifi.refresh(true) }
                    Toggle { on: Wifi.enabled; onToggled: Wifi.setEnabled(!Wifi.enabled) }
                }

                Text {
                    visible: Wifi.enabled && Wifi.networks.length === 0
                    text: Wifi.scanning ? "looking for networks…" : "no networks found"
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                }

                Repeater {
                    model: Wifi.enabled ? Wifi.networks.slice(0, 12) : []
                    ColumnLayout {
                        id: net
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: 10
                            color: net.modelData.active ? Qt.alpha(Theme.accent, 0.16) : (netHover.hovered ? Theme.surface0 : "transparent")
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10
                                Text { text: root.bars(net.modelData.signal); color: net.modelData.active ? Theme.accent : Theme.subtext; font.family: Theme.fontMono; font.pixelSize: 16 }
                                Text { text: net.modelData.ssid; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { visible: net.modelData.secure; text: "󰌾"; color: Theme.overlay; font.family: Theme.fontMono; font.pixelSize: 12 }
                                Text {
                                    text: Wifi.busySsid === net.modelData.ssid ? "connecting…" : (net.modelData.active ? "connected" : (Wifi.failedSsid === net.modelData.ssid ? "failed" : ""))
                                    color: Wifi.failedSsid === net.modelData.ssid ? Theme.red : Theme.subtext
                                    font.family: Theme.fontUi
                                    font.pixelSize: 11
                                }
                            }
                            HoverHandler { id: netHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    if (net.modelData.active)
                                        Wifi.disconnect(net.modelData.ssid)
                                    else if (net.modelData.secure && Wifi.failedSsid === net.modelData.ssid)
                                        root.asking = net.modelData.ssid
                                    else
                                        Wifi.connect(net.modelData.ssid, "")
                                }
                            }
                        }

                        Rectangle {
                            visible: root.asking === net.modelData.ssid
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 18
                            color: Theme.surface0
                            border.width: 1
                            border.color: Theme.accent
                            TextInput {
                                id: pw
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                passwordCharacter: "●"
                                color: Theme.text
                                font.family: Theme.fontUi
                                font.pixelSize: 13
                                onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                                onAccepted: {
                                    Wifi.connect(net.modelData.ssid, text)
                                    text = ""
                                    root.asking = ""
                                }
                                Keys.onEscapePressed: root.asking = ""
                                Text { visible: !pw.text; anchors.verticalCenter: parent.verticalCenter; text: "password for " + net.modelData.ssid; color: Theme.overlay; font: pw.font }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.surface1; Layout.topMargin: 4; Layout.bottomMargin: 4 }

                Heading {
                    glyph: "󰂯"
                    title: "Bluetooth"
                    SmallButton {
                        visible: root.adapter && root.adapter.enabled
                        label: root.adapter && root.adapter.discovering ? "stop scan" : "scan"
                        onClicked: root.adapter.discovering = !root.adapter.discovering
                    }
                    Toggle { on: root.adapter ? root.adapter.enabled : false; onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled }
                }

                Text {
                    visible: !root.adapter || (root.adapter.enabled && root.devices.length === 0)
                    text: !root.adapter ? "no bluetooth adapter" : "no devices yet, press scan"
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                }

                Repeater {
                    model: root.adapter && root.adapter.enabled ? root.devices.filter(d => d.paired || root.adapter.discovering).slice(0, 12) : []
                    Rectangle {
                        id: dev
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 10
                        color: modelData.connected ? Qt.alpha(Theme.accent, 0.16) : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 10
                            Text {
                                text: (dev.modelData.icon || "").indexOf("audio") >= 0 ? "󰋋" : ((dev.modelData.icon || "").indexOf("input") >= 0 ? "󰍽" : "󰂯")
                                color: dev.modelData.connected ? Theme.accent : Theme.subtext
                                font.family: Theme.fontMono
                                font.pixelSize: 16
                            }
                            Text { text: dev.modelData.name || dev.modelData.deviceName || "device"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { visible: dev.modelData.batteryAvailable; text: Math.round(dev.modelData.battery * 100) + "%"; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: 11 }
                            SmallButton {
                                label: dev.modelData.connected ? "disconnect" : (dev.modelData.paired ? "connect" : (dev.modelData.pairing ? "pairing…" : "pair"))
                                onClicked: {
                                    if (dev.modelData.connected)
                                        dev.modelData.disconnect()
                                    else if (dev.modelData.paired)
                                        dev.modelData.connect()
                                    else if (!dev.modelData.pairing)
                                        dev.modelData.pair()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
