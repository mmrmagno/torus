pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool enabled: false
    property var networks: []
    property bool scanning: false
    property string busySsid: ""
    property string failedSsid: ""
    property string wired: ""

    function refresh(rescan) {
        if (scan.running)
            return
        scanning = true
        scan.command = ["sh", "-c", "nmcli -t -f WIFI radio; nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2 == \"ethernet\" && $3 == \"connected\" {print \"WIRED:\" $1}'; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan " + (rescan ? "yes" : "auto")]
        scan.running = true
    }

    function setEnabled(on) {
        enabled = on
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"])
        later.restart()
    }

    function connect(ssid, password) {
        busySsid = ssid
        failedSsid = ""
        joiner.ssid = ssid
        joiner.password = password || ""
        joiner.command = password ? ["nmcli", "--ask", "dev", "wifi", "connect", ssid] : ["nmcli", "dev", "wifi", "connect", ssid]
        joiner.running = true
    }

    function disconnect(ssid) {
        Quickshell.execDetached(["nmcli", "con", "down", "id", ssid])
        later.restart()
    }

    Timer {
        id: later
        interval: 1500
        onTriggered: root.refresh(false)
    }

    Process {
        id: scan
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const seen = {}
                let wired = ""
                for (const line of text.split("\n")) {
                    if (line === "enabled" || line === "disabled") {
                        root.enabled = line === "enabled"
                        continue
                    }
                    if (line.startsWith("WIRED:")) {
                        wired = line.slice(6)
                        continue
                    }
                    const f = line.replace(/\\:/g, "\u0000").split(":").map(x => x.replace(/\u0000/g, ":"))
                    if (f.length < 4 || f[1] === "" || seen[f[1]])
                        continue
                    seen[f[1]] = true
                    out.push({ active: f[0] === "*", ssid: f[1], signal: Number(f[2]) || 0, secure: f[3] !== "" && f[3] !== "--" })
                }
                out.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
                root.networks = out
                root.wired = wired
                root.scanning = false
            }
        }
    }

    Process {
        id: joiner
        property string ssid: ""
        property string password: ""
        stdinEnabled: true
        onStarted: {
            if (password !== "") {
                write(password + "\n")
                password = ""
            }
        }
        onExited: code => {
            root.busySsid = ""
            root.failedSsid = code === 0 ? "" : ssid
            later.restart()
        }
    }
}
