pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs

Singleton {
    id: root

    property var holes: ({})

    function setHole(screenName, width) {
        if ((holes[screenName] || 0) === width)
            return
        const h = Object.assign({}, holes)
        h[screenName] = width
        holes = h
    }

    property string flashKind: ""
    property var flashData: ({})
    property bool armed: false
    property bool recording: false
    readonly property var shareApps: {
        const portal = n => n.name === "xdg-desktop-portal-hyprland" || String((n.properties || {})["media.name"] || "").startsWith("xdph")
        if (!Pipewire.nodes.values.some(portal))
            return []
        const apps = Pipewire.nodes.values
            .filter(n => (n.properties || {})["media.class"] === "Stream/Input/Video")
            .map(n => (n.properties || {})["application.process.binary"] || (n.properties || {})["application.name"] || n.name || "an app")
            .filter(a => !/gpu-screen-recorder|gsr/i.test(a))
        return Array.from(new Set(apps))
    }
    readonly property bool sharing: shareApps.length > 0
    // node properties (media class, names) only arrive once a node is bound
    PwObjectTracker { objects: Pipewire.nodes.values }
    property real recordStart: 0
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null
    property var modes: ({})
    readonly property string state: flashKind !== "" ? flashKind : (recording ? "recording" : (player ? "media" : "idle"))

    function flash(kind, data, ms) {
        if (!armed || (data && data.cat && !Feel.islandOn(data.cat)))
            return
        flashKind = kind
        flashData = data
        hide.interval = Math.round((ms || 1600) * Feel.islandSeconds / 1.6)
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

    Connections {
        target: Store
        function onTrashed(name, count) {
            root.flash("trash", { name: name, count: count }, 7000)
        }
    }

    Process {
        id: undoProc
        command: ["torus-trash", "undo"]
        onExited: code => {
            root.flash("osd", { icon: code === 0 ? "󰕌" : "󰩹", label: code === 0 ? "Back from the trash" : "Nothing to undo", value: -1 }, 1800)
            if (code === 0)
                Store.restored()
        }
    }

    function trashUndo() {
        if (flashKind === "trash")
            dismiss()
        if (undoProc.running)
            return
        undoProc.command = ["torus-trash", "undo"].concat(Store.lastTrash)
        Store.lastTrash = []
        undoProc.running = true
    }

    function shotAct(what) {
        const p = flashKind === "shot" ? (flashData.path || "") : ""
        if (!p)
            return false
        if (what === "Edit") {
            Quickshell.execDetached(["torus-launch", "satty", "--filename", p, "--output-filename", p, "--early-exit", "--copy-command", "wl-copy"])
        } else if (what === "Text") {
            Quickshell.execDetached(["torus-ocr", p])
        } else if (what === "Folder") {
            Quickshell.execDetached(["torus-launch", "xdg-open", p.substring(0, p.lastIndexOf("/"))])
        } else if (what === "Delete") {
            dismiss()
            Store.trash(p)
            return true
        } else {
            return false
        }
        dismiss()
        return true
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
            flash("osd", { icon: "󰎆", label: name + "  " + Math.round(p.volume * 100) + "%", value: p.volume, cat: "volume" })
            return
        }
        const key = (p.desktopEntry || p.identity || "").toLowerCase()
        const node = Pipewire.nodes.values.find(n => n.isStream && n.audio && key !== "" && [n.properties["application.name"], n.properties["application.process.binary"], n.name].some(v => v && String(v).toLowerCase().includes(key)))
        if (!node) {
            flash("osd", { icon: "󰎆", label: name + ": no volume control", value: -1, cat: "volume" })
            return
        }
        node.audio.volume = Math.max(0, Math.min(1, node.audio.volume + delta))
        flash("osd", { icon: "󰎆", label: name + "  " + Math.round(node.audio.volume * 100) + "%", value: node.audio.volume, cat: "volume" })
    }

    readonly property bool watchingDevices: DeviceWatch.startedAt > 0
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isLaptopBattery
    readonly property bool charging: hasBattery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged || battery.state === UPowerDeviceState.PendingCharge)
    property int warnedAt: 100

    function batteryCheck() {
        if (!hasBattery)
            return
        const pct = Math.round(battery.percentage * 100)
        if (charging) {
            warnedAt = 100
            return
        }
        for (const level of [5, 15]) {
            if (pct <= level && warnedAt > level) {
                warnedAt = level
                flash("osd", { icon: level === 5 ? "󰂃" : "󰁺", label: "Battery " + pct + "%" + (level === 5 ? ", plug in now" : ", running low"), value: battery.percentage, cat: "battery" }, 6000)
                if (level === 5)
                    Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "torus", "-i", "battery-caution", "Battery at " + pct + "%", "Plug in the charger, the laptop will sleep soon"])
                return
            }
        }
    }

    onChargingChanged: {
        if (!hasBattery || !armed)
            return
        flash("osd", { icon: charging ? "󰂄" : "󰁹", label: (charging ? "Charging " : "On battery ") + Math.round(battery.percentage * 100) + "%", value: battery.percentage, cat: "battery" }, 2200)
        Store.sound(charging ? "plug" : "unplug")
        batteryCheck()
    }

    Connections {
        target: root.battery
        function onPercentageChanged() {
            root.batteryCheck()
        }
    }

    function setPower(p) {
        PowerProfiles.profile = p
        const names = ["Power saver", "Balanced", "Performance"]
        flash("osd", { icon: p === PowerProfile.Performance ? "󰓅" : (p === PowerProfile.PowerSaver ? "󰾆" : "󰾅"), label: names[p], value: -1 }, 1800)
    }

    function cyclePower() {
        const order = [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        const i = order.indexOf(PowerProfiles.profile)
        setPower(order[(i + 1) % order.length])
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
        flash("notification", { summary: n.summary, body: n.body, app: n.appName, icon: n.appIcon, image: n.image, cat: "notifications" }, 4000)
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
            root.flash("osd", { icon: a.muted ? "󰝟" : "󰕾", label: Math.round(a.volume * 100) + "%", value: a.muted ? 0 : a.volume, cat: "volume" })
            if (root.armed)
                Store.sound("tick")
        }
        function onMutedChanged() {
            const a = Pipewire.defaultAudioSink.audio
            root.flash("osd", { icon: a.muted ? "󰝟" : "󰕾", label: a.muted ? "muted" : Math.round(a.volume * 100) + "%", value: a.muted ? 0 : a.volume, cat: "volume" })
            if (root.armed && !a.muted)
                Store.sound("tick")
        }
    }

    Connections {
        target: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
        function onMutedChanged() {
            const a = Pipewire.defaultAudioSource.audio
            root.flash("osd", { icon: a.muted ? "󰍭" : "󰍬", label: a.muted ? "mic muted" : "mic on", value: -1, cat: "volume" })
            if (root.armed)
                Store.sound("tick")
        }
    }

    Connections {
        target: Backlight
        function onPercentChanged() {
            root.flash("osd", { icon: "󰃟", label: Backlight.percent + "%", value: Backlight.percent / 100 })
            if (root.armed)
                Store.sound("tick")
        }
    }

    property string lastLayout: ""

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return
            const kb = event.data.split(",")[0]
            const layout = event.data.split(",").slice(1).join(",")
            if (/virtual|wtype|ydotool/i.test(kb) || layout === "error" || layout === root.lastLayout)
                return
            root.lastLayout = layout
            root.flash("osd", { icon: "󰌌", label: layout, value: -1 })
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
                root.flash("osd", { icon: d.connected ? icon : "󰂲", label: d.name + (d.connected ? bat : "  disconnected"), value: d.connected && d.batteryAvailable ? d.battery : -1, cat: "devices" }, 2600)
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
