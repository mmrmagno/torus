import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs

ColumnLayout {
    id: root

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var inputs: nodes.filter(n => !n.isSink && !n.isStream && !(n.name || "").endsWith(".monitor"))
    readonly property var streams: nodes.filter(n => n.isStream && n.isSink)

    function label(n) {
        const p = n.properties || {}
        return p["application.name"] || n.nickname || n.description || n.name || "audio"
    }

    function iconOf(n) {
        const p = n.properties || {}
        const name = p["application.icon-name"] || p["application.process.binary"] || p["application.name"] || ""
        const e = name ? DesktopEntries.heuristicLookup(name) : null
        return Quickshell.iconPath(e ? e.icon : name.toLowerCase(), "audio-volume-high")
    }

    spacing: 10

    PwObjectTracker { objects: root.nodes }

    component DeviceRow: Flow {
        id: devRow
        property var devices: []
        property var current: null
        property string glyph: ""
        signal picked(var node)
        Layout.fillWidth: true
        spacing: 6
        Text {
            text: devRow.glyph
            color: Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: 15
            height: 28
            verticalAlignment: Text.AlignVCenter
        }
        Repeater {
            model: devRow.devices
            Rectangle {
                required property var modelData
                readonly property bool on: devRow.current && devRow.current.id === modelData.id
                height: 28
                width: devText.implicitWidth + 24
                radius: 14
                color: on ? Theme.accent : (devHover.hovered ? Theme.surface1 : Theme.surface0)
                Behavior on color { ColorAnimation { duration: 140 } }
                Text {
                    id: devText
                    anchors.centerIn: parent
                    text: modelData.nickname || modelData.description || modelData.name
                    color: parent.on ? Theme.crust : Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 220)
                }
                HoverHandler { id: devHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: devRow.picked(parent.modelData) }
            }
        }
    }

    DeviceRow {
        glyph: "󰓃"
        devices: root.outputs
        current: Pipewire.defaultAudioSink
        onPicked: node => Pipewire.preferredDefaultAudioSink = node
    }

    DeviceRow {
        glyph: "󰍬"
        devices: root.inputs
        current: Pipewire.defaultAudioSource
        onPicked: node => Pipewire.preferredDefaultAudioSource = node
    }

    Text {
        visible: root.streams.length === 0
        text: "nothing is playing"
        color: Theme.overlay
        font.family: Theme.fontUi
        font.pixelSize: 12
    }

    Repeater {
        model: root.streams
        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 10
            IconImage {
                implicitSize: 20
                source: root.iconOf(parent.modelData)
            }
            Text {
                Layout.preferredWidth: 120
                text: root.label(parent.modelData)
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            VolumeSlider {
                Layout.fillWidth: true
                audio: parent.modelData.audio
            }
            Text {
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignRight
                text: parent.modelData.audio ? Math.round(parent.modelData.audio.volume * 100) + "%" : ""
                color: Theme.subtext
                font.family: Theme.fontMono
                font.pixelSize: 11
            }
            Text {
                readonly property bool muted: parent.modelData.audio && parent.modelData.audio.muted
                text: muted ? "󰝟" : "󰕾"
                color: muted ? Theme.red : Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: 15
                TapHandler { onTapped: if (parent.parent.modelData.audio) parent.parent.modelData.audio.muted = !parent.parent.modelData.audio.muted }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }
    }
}
