import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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

    screen: Store.screenFor("network")
    visible: Store.isOpen("network") || motion.leaving
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
    implicitHeight: Math.floor(Math.min(720, Store.panelRoom(screen, 16)))
    mask: Region { item: netFrame }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: !Store.isOpen("network") || Store.moving ? WlrKeyboardFocus.None : (root.asking !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)

    component Toggle: Rectangle {
        id: tg
        property bool on: false
        property string label: "toggle"
        signal toggled
        activeFocusOnTab: visible
        onActiveFocusChanged: if (activeFocus) Store.focusLabel = label
        Keys.onReturnPressed: tg.toggled()
        Keys.onEnterPressed: tg.toggled()
        Keys.onSpacePressed: tg.toggled()
        FocusRing { on: tg.activeFocus; baseRadius: tg.radius }
        width: 38
        height: 22
        radius: 11
        color: on ? Theme.accent : Theme.surface1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Rectangle {
            x: tg.on ? tg.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: Theme.rSm
            color: tg.on ? Theme.crust : Theme.text
            Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
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
        spacing: Theme.sp4
        Text { text: hd.glyph; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsXl }
        Text { text: hd.title; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsLg; font.weight: Font.DemiBold; Layout.fillWidth: true }
        Row { id: tail; spacing: Theme.sp4 }
    }

    component SmallButton: Rectangle {
        id: sb
        property string label: ""
        property bool danger: false
        signal clicked
        activeFocusOnTab: visible
        onActiveFocusChanged: if (activeFocus) Store.focusLabel = label
        Keys.onReturnPressed: sb.clicked()
        Keys.onEnterPressed: sb.clicked()
        Keys.onSpacePressed: sb.clicked()
        FocusRing { on: sb.activeFocus; baseRadius: sb.radius }
        width: sbText.implicitWidth + 20
        height: 24
        radius: Theme.rCard
        color: sbHover.hovered ? (danger ? Theme.red : Theme.accent) : Theme.surface1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Text { id: sbText; anchors.centerIn: parent; text: sb.label; color: sbHover.hovered ? Theme.crust : Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
        HoverHandler { id: sbHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: sb.clicked() }
    }

    HyprlandFocusGrab {
        active: Store.isOpen("network") && root.backingWindowVisible
        windows: [root]
        onCleared: Store.setOpen("network", false)
    }

    Rectangle {
        id: netFrame
        Connections {
            target: root
            function onVisibleChanged() {
                if (root.visible)
                    netFrame.forceActiveFocus()
            }
        }
        focus: true
        Keys.onEscapePressed: Store.setOpen("network", false)
        PanelMotion {
            id: motion
            target: netFrame
            shown: Store.isOpen("network") && !Store.moving
        }
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(body.implicitHeight + 32 + hintBar.height + Theme.sp5, root.implicitHeight)
        Behavior on height { enabled: root.visible; NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
        transformOrigin: Item.TopRight
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        clip: true

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.margins: 11
            anchors.bottomMargin: 16 + hintBar.height + Theme.sp5
            contentHeight: body.implicitHeight + 10
            clip: true

            ColumnLayout {
                id: body
                x: 5
                y: 5
                width: parent.width - 10
                spacing: Theme.sp5

                RowLayout {
                    Layout.fillWidth: true
                    visible: Wifi.wired !== ""
                    spacing: Theme.sp4
                    Text { text: "󰈀"; color: Theme.green; font.family: Theme.fontMono; font.pixelSize: Theme.fsXl }
                    Text { text: "Wired · " + Wifi.wired + " connected"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd; Layout.fillWidth: true }
                }

                Heading {
                    glyph: "󰖩"
                    title: "Wi-Fi"
                    SmallButton { label: Wifi.scanning ? "scanning…" : "rescan"; visible: Wifi.enabled; onClicked: Wifi.refresh(true) }
                    Toggle { label: "Wi-Fi"; on: Wifi.enabled; onToggled: Wifi.setEnabled(!Wifi.enabled) }
                }

                Text {
                    visible: Wifi.enabled && Wifi.networks.length === 0
                    text: Wifi.scanning ? "looking for networks…" : "no networks found"
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                }

                Repeater {
                    model: Wifi.enabled ? Wifi.networks.slice(0, 12) : []
                    ColumnLayout {
                        id: net
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.sp3

                        function activate() {
                            if (net.modelData.active)
                                Wifi.disconnect(net.modelData.ssid)
                            else if (net.modelData.secure && Wifi.failedSsid === net.modelData.ssid)
                                root.asking = net.modelData.ssid
                            else
                                Wifi.connect(net.modelData.ssid, "")
                        }

                        Rectangle {
                            id: netRow
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: Theme.radius
                            activeFocusOnTab: true
                            onActiveFocusChanged: if (activeFocus) Store.focusLabel = net.modelData.ssid
                            Keys.onReturnPressed: net.activate()
                            Keys.onEnterPressed: net.activate()
                            Keys.onSpacePressed: net.activate()
                            FocusRing { on: netRow.activeFocus; baseRadius: netRow.radius }
                            color: net.modelData.active ? Qt.alpha(Theme.accent, 0.16) : (netHover.hovered ? Theme.surface0 : "transparent")
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: Theme.sp5
                                Text { text: root.bars(net.modelData.signal); color: net.modelData.active ? Theme.accent : Theme.subtext; font.family: Theme.fontMono; font.pixelSize: Theme.fsXl }
                                Text { text: net.modelData.ssid; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsBase; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { visible: net.modelData.secure; text: "󰌾"; color: Theme.overlay; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd }
                                Text {
                                    text: Wifi.busySsid === net.modelData.ssid ? "connecting…" : (net.modelData.active ? "connected" : (Wifi.failedSsid === net.modelData.ssid ? "failed" : ""))
                                    color: Wifi.failedSsid === net.modelData.ssid ? Theme.red : Theme.subtext
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsSm
                                }
                            }
                            HoverHandler { id: netHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: net.activate() }
                        }

                        Rectangle {
                            visible: root.asking === net.modelData.ssid
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: Theme.rPanel
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
                                font.pixelSize: Theme.fsBase
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
                    Toggle { label: "Bluetooth"; on: root.adapter ? root.adapter.enabled : false; onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled }
                }

                Text {
                    visible: !root.adapter || (root.adapter.enabled && root.devices.length === 0)
                    text: !root.adapter ? "no bluetooth adapter" : "no devices yet, press scan"
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                }

                Repeater {
                    model: root.adapter && root.adapter.enabled ? root.devices.filter(d => d.paired || root.adapter.discovering).slice(0, 12) : []
                    Rectangle {
                        id: dev
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Theme.radius
                        color: modelData.connected ? Qt.alpha(Theme.accent, 0.16) : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: Theme.sp5
                            Text {
                                text: (dev.modelData.icon || "").indexOf("audio") >= 0 ? "󰋋" : ((dev.modelData.icon || "").indexOf("input") >= 0 ? "󰍽" : "󰂯")
                                color: dev.modelData.connected ? Theme.accent : Theme.subtext
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsXl
                            }
                            Text { text: dev.modelData.name || dev.modelData.deviceName || "device"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsBase; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { visible: dev.modelData.batteryAvailable; text: Math.round(dev.modelData.battery * 100) + "%"; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: Theme.fsSm }
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

        ScrollFade { flick: scroller }

        KeyHints {
            id: hintBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16
            hints: [["Tab", "move"], ["↵", "press"], ["Esc", "close"]]
        }
    }
}
