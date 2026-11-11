pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs

Singleton {
    id: root

    function appOf(n) {
        const p = n.properties || {}
        return p["application.process.binary"] || p["application.name"] || n.description || n.name || "an app"
    }

    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && !n.isSink)
    readonly property var micApps: streams.filter(n => n.audio).map(appOf).filter(a => a !== "gpu-screen-recorder")
    readonly property var cameraStreams: Island.sharing ? [] : Pipewire.nodes.values.filter(n => (n.properties || {})["media.class"] === "Stream/Input/Video").map(appOf)
    property var cameraApps: []
    readonly property var camera: cameraStreams.concat(cameraApps)
    readonly property bool mic: micApps.length > 0
    readonly property bool cam: camera.length > 0

    PwObjectTracker { objects: root.streams }

    // browsers open the webcam directly, without PipeWire, so look at who holds the device
    Process {
        id: probe
        command: ["sh", "-c", "for p in $(fuser /dev/video* 2> /dev/null); do cat /proc/$p/comm; done 2> /dev/null | grep -vxE 'pipewire|wireplumber' | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: root.cameraApps = text.split("\n").filter(x => x.trim() !== "")
        }
    }
    Timer {
        interval: 4000
        repeat: true
        running: !Store.lockSecure
        triggeredOnStart: true
        onTriggered: if (!probe.running) probe.running = true
    }
}
