pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import qs

Singleton {
    id: root

    property string flashKind: ""
    property var flashData: ({})
    property bool armed: false
    property bool recording: false
    property real recordStart: 0
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null
    property var modes: ({})
    readonly property string state: flashKind !== "" ? flashKind : (recording ? "recording" : (player ? "media" : "idle"))

    function flash(kind, data, ms) {
        if (!armed)
            return
        flashKind = kind
        flashData = data
        hide.interval = ms || 1600
        hide.restart()
    }

    function hold(on) {
        if (on)
            hide.stop()
        else if (flashKind !== "")
            hide.restart()
    }

    function dismiss() {
        hide.stop()
        flashKind = ""
    }

    function report(screenName, mode) {
        const m = Object.assign({}, modes)
        m[screenName] = mode
        modes = m
    }

    function nudgePlayerVolume(delta) {
        const p = player
        if (!p)
            return
        const name = p.identity || "player"
        if (p.volumeSupported) {
            p.volume = Math.max(0, Math.min(1, p.volume + delta))
            flash("osd", { icon: "󰎆", label: name + "  " + Math.round(p.volume * 100) + "%", value: p.volume })
            return
        }
        const key = (p.desktopEntry || p.identity || "").toLowerCase()
        const node = Pipewire.nodes.values.find(n => n.isStream && n.audio && key !== "" && [n.properties["application.name"], n.properties["application.process.binary"], n.name].some(v => v && String(v).toLowerCase().includes(key)))
        if (!node) {
            flash("osd", { icon: "󰎆", label: name + ": no volume control", value: -1 })
            return
        }
        node.audio.volume = Math.max(0, Math.min(1, node.audio.volume + delta))
        flash("osd", { icon: "󰎆", label: name + "  " + Math.round(node.audio.volume * 100) + "%", value: node.audio.volume })
    }

    property bool caps: false
    property bool capsQuiet: false

    function checkCaps() {
        capsQuiet = false
        if (!capsProc.running)
            capsProc.running = true
    }

    function readCaps() {
        capsQuiet = true
        if (!capsProc.running)
            capsProc.running = true
    }

    function notify(n) {
        flash("notification", { summary: n.summary, body: n.body, app: n.appName, icon: n.appIcon, image: n.image }, 4000)
    }

    Binding {
        target: Store
        property: "osdVisible"
        value: root.flashKind === "osd"
    }

    Timer {
        id: hide
        onTriggered: root.flashKind = ""
    }

    Timer {
        interval: 2500
        running: true
        onTriggered: root.armed = true
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() {
            const a = Pipewire.defaultAudioSink.audio
            root.flash("osd", { icon: a.muted ? "󰝟" : "󰕾", label: Math.round(a.volume * 100) + "%", value: a.muted ? 0 : a.volume })
        }
        function onMutedChanged() {
            const a = Pipewire.defaultAudioSink.audio
            root.flash("osd", { icon: a.muted ? "󰝟" : "󰕾", label: a.muted ? "muted" : Math.round(a.volume * 100) + "%", value: a.muted ? 0 : a.volume })
        }
    }

    Connections {
        target: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
        function onMutedChanged() {
            const a = Pipewire.defaultAudioSource.audio
            root.flash("osd", { icon: a.muted ? "󰍭" : "󰍬", label: a.muted ? "mic muted" : "mic on", value: -1 })
        }
    }

    Connections {
        target: Backlight
        function onPercentChanged() {
            root.flash("osd", { icon: "󰃟", label: Backlight.percent + "%", value: Backlight.percent / 100 })
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                root.flash("osd", { icon: "󰌌", label: event.data.split(",").slice(1).join(","), value: -1 })
        }
    }

    PwObjectTracker { objects: Pipewire.nodes.values.filter(n => n.isStream) }

    Process {
        id: capsProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const k = JSON.parse(text).keyboards.find(k => k.main) || {}
                    root.caps = !!k.capsLock
                    if (root.capsQuiet)
                        return
                    root.flash("osd", { icon: k.capsLock ? "󰪛" : "󰬶", label: k.capsLock ? "CAPS LOCK ON" : "caps lock off", value: -1 })
                } catch (e) {}
            }
        }
    }

    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                const d = modelData
                const icon = (d.icon || "").includes("headset") || (d.icon || "").includes("audio") ? "󰋋" : ((d.icon || "").includes("phone") ? "󰏲" : "󰂯")
                const bat = d.connected && d.batteryAvailable ? "  ·  " + Math.round(d.battery * 100) + "%" : ""
                root.flash("osd", { icon: d.connected ? icon : "󰂲", label: d.name + (d.connected ? bat : "  disconnected"), value: d.connected && d.batteryAvailable ? d.battery : -1 }, 2600)
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "mkdir -p \"$1\" && touch \"$1/recording\"", "sh", Store.stateDir]
        onExited: recFile.path = Store.stateDir + "/recording"
    }

    FileView {
        id: recFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const t = parseInt(text())
            root.recordStart = isNaN(t) ? Date.now() : t * 1000
            root.recording = !isNaN(t)
        }
        onLoadFailed: root.recording = false
    }
}
