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
    readonly property var streams: nodes.filter(n => n.isStream && n.isSink && !quiet(n))
    property var firstSeen: ({})
    readonly property int settleMs: 1000

    function quiet(n) {
        const p = n.properties || {}
        const role = (p["media.role"] || "").toLowerCase()
        const app = (p["application.name"] || "").toLowerCase()
        const bin = (p["application.process.binary"] || "").toLowerCase()
        return role === "event" || role === "notification" || /^pw-(play|cat)$/.test(app) || /^pw-(play|cat)$/.test(bin)
    }

    function nodeOf(id) {
        return streams.find(n => n.id === id) || null
    }

    function sync() {
        const t = Date.now()
        const seen = {}
        let pending = false
        for (const n of streams) {
            seen[n.id] = firstSeen[n.id] || t
            if (t - seen[n.id] < settleMs)
                pending = true
        }
        firstSeen = seen
        const want = streams.filter(n => t - seen[n.id] >= settleMs).map(n => n.id)
        for (let i = rows.count - 1; i >= 0; i--)
            if (want.indexOf(rows.get(i).nid) < 0)
                rows.remove(i)
        for (const id of want) {
            let has = false
            for (let i = 0; i < rows.count && !has; i++)
                has = rows.get(i).nid === id
            if (!has)
                rows.append({ nid: id })
        }
        settle.running = pending
        const names = []
        for (let i = 0; i < rows.count; i++) {
            const n = nodeOf(rows.get(i).nid)
            if (n)
                names.push(label(n) + "=" + (n.audio ? Math.round(n.audio.volume * 100) : 0))
        }
        Store.mixerShown = names.join("|")
    }

    onStreamsChanged: sync()
    Component.onCompleted: sync()

    ListModel { id: rows }

    Timer {
        id: settle
        interval: 200
        repeat: true
        onTriggered: root.sync()
    }

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

    spacing: Theme.sp5

    PwObjectTracker { objects: root.nodes }

    component DeviceRow: Flow {
        id: devRow
        property var devices: []
        property var current: null
        property string glyph: ""
        signal picked(var node)
        Layout.fillWidth: true
        spacing: Theme.sp3
        Text {
            text: devRow.glyph
            color: Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: Theme.icon
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
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                Text {
                    id: devText
                    anchors.centerIn: parent
                    text: modelData.nickname || modelData.description || modelData.name
                    color: parent.on ? Theme.crust : Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSm
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

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(streamList.contentHeight, rows.count === 0 ? idle.implicitHeight : 0)
        Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }

        Text {
            id: idle
            opacity: rows.count === 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durMed } }
            text: "nothing is playing"
            color: Theme.overlay
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsMd
        }

        ListView {
            id: streamList
            anchors.fill: parent
            interactive: false
            spacing: Theme.sp5
            model: rows
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMed; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "x"; from: -18; to: 0; duration: Theme.durMed; easing.type: Easing.OutCubic }
                }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: Theme.durFast; easing.type: Easing.InCubic }
                    NumberAnimation { property: "x"; to: 18; duration: Theme.durFast; easing.type: Easing.InCubic }
                }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: Theme.durMed; easing.type: Easing.OutCubic }
            }
            delegate: RowLayout {
                id: streamRow
                required property int nid
                readonly property var node: root.nodeOf(nid)
                width: streamList.width
                spacing: Theme.sp5
                IconImage {
                    implicitSize: 20
                    source: streamRow.node ? root.iconOf(streamRow.node) : ""
                }
                Text {
                    Layout.preferredWidth: 120
                    text: streamRow.node ? root.label(streamRow.node) : ""
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                    elide: Text.ElideRight
                }
                VolumeSlider {
                    Layout.fillWidth: true
                    audio: streamRow.node ? streamRow.node.audio : null
                }
                Text {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: streamRow.node && streamRow.node.audio ? Math.round(streamRow.node.audio.volume * 100) + "%" : ""
                    color: Theme.subtext
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsSm
                }
                Text {
                    readonly property bool muted: streamRow.node && streamRow.node.audio && streamRow.node.audio.muted
                    text: muted ? "󰝟" : "󰕾"
                    color: muted ? Theme.red : Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.icon
                    TapHandler { onTapped: if (streamRow.node && streamRow.node.audio) streamRow.node.audio.muted = !streamRow.node.audio.muted }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }
}
