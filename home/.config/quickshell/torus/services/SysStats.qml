pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpu: 0
    property real memUsed: 0
    property real memTotal: 1
    property int cpuTemp: -1
    property int gpuBusy: -1
    property int gpuTemp: -1
    property string cpuTempPath: ""
    property string gpuBusyPath: ""
    property string gpuTempPath: ""
    property var lastCpu: [0, 0]

    readonly property real memPercent: memTotal > 0 ? memUsed / memTotal * 100 : 0

    function readInt(view) {
        const v = parseInt(view.text())
        return isNaN(v) ? -1 : v
    }

    Process {
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); case $n in coretemp|k10temp|zenpower) echo cpu $h/temp1_input;; amdgpu) echo gpu $h/temp1_input;; esac; done; ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | sed 's/^/busy /'"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const [kind, path] = line.split(" ")
                if (kind === "cpu" && !root.cpuTempPath)
                    root.cpuTempPath = path
                else if (kind === "gpu" && !root.gpuTempPath)
                    root.gpuTempPath = path
                else if (kind === "busy" && !root.gpuBusyPath)
                    root.gpuBusyPath = path
            }
        }
    }

    FileView { id: stat; path: "/proc/stat" }
    FileView { id: meminfo; path: "/proc/meminfo" }
    FileView { id: cpuTempFile; path: root.cpuTempPath; printErrors: false }
    FileView { id: gpuTempFile; path: root.gpuTempPath; printErrors: false }
    FileView { id: gpuBusyFile; path: root.gpuBusyPath; printErrors: false }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload()
            meminfo.reload()
            const f = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = f[3] + (f[4] || 0)
            const total = f.reduce((a, b) => a + b, 0)
            const dt = total - root.lastCpu[0]
            if (dt > 0 && root.lastCpu[0] > 0)
                root.cpu = (1 - (idle - root.lastCpu[1]) / dt) * 100
            root.lastCpu = [total, idle]
            const m = {}
            for (const l of meminfo.text().split("\n")) {
                const p = l.split(/:\s+/)
                if (p.length === 2)
                    m[p[0]] = parseInt(p[1])
            }
            root.memTotal = (m.MemTotal || 1) / 1048576
            root.memUsed = ((m.MemTotal || 0) - (m.MemAvailable || 0)) / 1048576
            if (root.cpuTempPath) {
                cpuTempFile.reload()
                const t = root.readInt(cpuTempFile)
                root.cpuTemp = t < 0 ? -1 : Math.round(t / 1000)
            }
            if (root.gpuTempPath) {
                gpuTempFile.reload()
                const t = root.readInt(gpuTempFile)
                root.gpuTemp = t < 0 ? -1 : Math.round(t / 1000)
            }
            if (root.gpuBusyPath) {
                gpuBusyFile.reload()
                root.gpuBusy = root.readInt(gpuBusyFile)
            }
        }
    }
}
