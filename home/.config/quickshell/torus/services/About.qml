pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var rows: []

    Process {
        command: ["fastfetch", "--format", "json", "--structure", "OS:Kernel:Uptime:Packages:CPU:GPU:Memory:WM"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    const out = []
                    for (const m of j) {
                        if (!m.result)
                            continue
                        const r = m.result
                        let v = ""
                        switch (m.type) {
                        case "OS": v = r.prettyName || r.name; break
                        case "Kernel": v = r.release; break
                        case "Uptime": v = Math.round(r.uptime / 3600000) + " h"; break
                        case "Packages": v = r.all + " pkgs"; break
                        case "CPU": v = r.cpu; break
                        case "GPU": v = r.length ? r[0].name : ""; break
                        case "Memory": v = (r.total / 1073741824).toFixed(0) + " GiB"; break
                        case "WM": v = r.prettyName + " " + (r.version || ""); break
                        }
                        out.push({ k: m.type.toLowerCase(), v: v })
                    }
                    root.rows = out
                } catch (e) {
                    root.rows = []
                }
            }
        }
    }
}
