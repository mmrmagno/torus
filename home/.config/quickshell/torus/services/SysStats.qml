pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property alias cpu: kept.cpu
    property alias memUsed: kept.memUsed
    property alias memTotal: kept.memTotal

    PersistentProperties {
        id: kept
        reloadableId: "torus-sysstats"
        property real cpu: 0
        property real memUsed: 0
        property real memTotal: 1
    }
    property int cpuTemp: -1
    property int gpuBusy: -1
    property int gpuTemp: -1
    property string cpuTempPath: ""
    property string gpuBusyPath: ""
    property string gpuTempPath: ""
    property var lastCpu: [0, 0]
    property var lastCores: []
    property var cores: []
    property string load: ""
    property real memCached: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property int cpuMhz: -1
    property string gpuDir: ""
    property string gpuHwmon: ""
    property real vramUsed: -1
    property real vramTotal: -1
    property int gpuWatts: -1
    property int gpuMhz: -1
    property int gpuHotspot: -1

    property var cpuHist: []
    property var gpuHist: []
    property var memHist: []
    property var rxHist: []
    property var txHist: []
    property real rxRate: 0
    property real txRate: 0
    property var lastNet: [0, 0, 0]

    function push(arr, v) {
        return arr.concat([v]).slice(-30)
    }

    function rate(bps) {
        if (bps < 1024)
            return Math.round(bps) + " B/s"
        if (bps < 1048576)
            return (bps / 1024).toFixed(bps < 10240 ? 1 : 0) + " KB/s"
        return (bps / 1048576).toFixed(1) + " MB/s"
    }

    readonly property real memPercent: memTotal > 0 ? memUsed / memTotal * 100 : 0

    function readInt(view) {
        const v = parseInt(view.text())
        return isNaN(v) ? -1 : v
    }

    Process {
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); case $n in coretemp|k10temp|zenpower) echo cpu $h/temp1_input;; amdgpu) echo gpu $h/temp1_input;; esac; done; ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | sed 's/^/busy /'; for d in /sys/class/drm/card*/device; do [ -f $d/mem_info_vram_total ] && echo vram $d; done; for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name 2>/dev/null)\" = amdgpu ] && echo gpuhw $h; done"]
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
                else if (kind === "vram" && !root.gpuDir)
                    root.gpuDir = path
                else if (kind === "gpuhw" && !root.gpuHwmon)
                    root.gpuHwmon = path
            }
        }
    }

    FileView { id: stat; path: "/proc/stat" }
    FileView { id: meminfo; path: "/proc/meminfo" }
    FileView { id: cpuTempFile; path: root.cpuTempPath; printErrors: false }
    FileView { id: gpuTempFile; path: root.gpuTempPath; printErrors: false }
    FileView { id: gpuBusyFile; path: root.gpuBusyPath; printErrors: false }
    FileView { id: loadFile; path: "/proc/loadavg" }
    FileView { id: netdev; path: "/proc/net/dev" }
    FileView { id: cpuinfo; path: "/proc/cpuinfo" }
    FileView { id: vramUsedFile; path: root.gpuDir ? root.gpuDir + "/mem_info_vram_used" : ""; printErrors: false }
    FileView { id: vramTotalFile; path: root.gpuDir ? root.gpuDir + "/mem_info_vram_total" : ""; printErrors: false }
    FileView { id: powerFile; path: root.gpuHwmon ? root.gpuHwmon + "/power1_average" : ""; printErrors: false }
    FileView { id: sclkFile; path: root.gpuHwmon ? root.gpuHwmon + "/freq1_input" : ""; printErrors: false }
    FileView { id: hotFile; path: root.gpuHwmon ? root.gpuHwmon + "/temp2_input" : ""; printErrors: false }

    Timer {
        interval: Calm.active ? 5000 : 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload()
            meminfo.reload()
            const lines = stat.text().split("\n")
            const f = lines[0].trim().split(/\s+/).slice(1).map(Number)
            const prev = root.lastCores
            const now = []
            const pct = []
            for (const l of lines) {
                if (!/^cpu\d/.test(l))
                    continue
                const v = l.trim().split(/\s+/).slice(1).map(Number)
                const tot = v.reduce((a, b) => a + b, 0)
                const idl = v[3] + (v[4] || 0)
                const i = now.length
                now.push([tot, idl])
                const d = prev[i] ? tot - prev[i][0] : 0
                pct.push(d > 0 ? (1 - (idl - prev[i][1]) / d) * 100 : 0)
            }
            root.lastCores = now
            root.cores = pct
            loadFile.reload()
            root.load = loadFile.text().split(" ").slice(0, 3).join("  ")
            cpuinfo.reload()
            const mhz = cpuinfo.text().split("\n").filter(l => l.startsWith("cpu MHz")).map(l => parseFloat(l.split(":")[1]))
            root.cpuMhz = mhz.length ? Math.round(mhz.reduce((a, b) => a + b, 0) / mhz.length) : -1
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
            root.memCached = ((m.Cached || 0) + (m.Buffers || 0)) / 1048576
            root.swapTotal = (m.SwapTotal || 0) / 1048576
            root.swapUsed = ((m.SwapTotal || 0) - (m.SwapFree || 0)) / 1048576
            if (root.gpuDir) {
                vramUsedFile.reload()
                vramTotalFile.reload()
                root.vramUsed = root.readInt(vramUsedFile) / 1073741824
                root.vramTotal = root.readInt(vramTotalFile) / 1073741824
            }
            if (root.gpuHwmon) {
                powerFile.reload()
                sclkFile.reload()
                hotFile.reload()
                const w = root.readInt(powerFile)
                root.gpuWatts = w < 0 ? -1 : Math.round(w / 1000000)
                const hz = root.readInt(sclkFile)
                root.gpuMhz = hz < 0 ? -1 : Math.round(hz / 1000000)
                const h = root.readInt(hotFile)
                root.gpuHotspot = h < 0 ? -1 : Math.round(h / 1000)
            }
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
            netdev.reload()
            let rx = 0
            let tx = 0
            for (const l of netdev.text().split("\n").slice(2)) {
                const parts = l.trim().split(/[:\s]+/)
                if (parts.length < 10 || parts[0] === "lo" || /^(veth|docker|br-|virbr|tailscale|wg)/.test(parts[0]))
                    continue
                rx += Number(parts[1]) || 0
                tx += Number(parts[9]) || 0
            }
            const t = Date.now()
            if (root.lastNet[2] > 0) {
                const sec = (t - root.lastNet[2]) / 1000
                root.rxRate = Math.max(0, (rx - root.lastNet[0]) / sec)
                root.txRate = Math.max(0, (tx - root.lastNet[1]) / sec)
            }
            root.lastNet = [rx, tx, t]
            root.cpuHist = root.push(root.cpuHist, root.cpu / 100)
            root.gpuHist = root.push(root.gpuHist, Math.max(0, root.gpuBusy) / 100)
            root.memHist = root.push(root.memHist, root.memPercent / 100)
            root.rxHist = root.push(root.rxHist, root.rxRate)
            root.txHist = root.push(root.txHist, root.txRate)
        }
    }
}
