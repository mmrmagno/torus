pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property var servers: []
    readonly property string home: Quickshell.env("HOME")

    function tilde(p) {
        return p === home || p.startsWith(home + "/") ? "~" + p.slice(home.length) : p
    }

    function find(port) {
        for (const s of servers)
            if (s.port === port)
                return s
        return null
    }

    function open(s) {
        Quickshell.execDetached(["torus-launch", "xdg-open", "http://localhost:" + s.port])
    }

    function stop(s) {
        stopProc.exec(["torus-ports", "stop", String(s.pid)])
    }

    function refresh() {
        if (!listProc.running)
            listProc.running = true
    }

    Process {
        id: listProc
        command: ["torus-ports", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.servers = text.split("\n").filter(l => l).map(l => {
                const f = l.split("\t")
                return { port: Number(f[0]), pid: Number(f[1]), comm: f[2] || "", cwd: f[3] || "", cmd: f[4] || "", addr: f[5] || "" }
            })
        }
    }

    Process {
        id: stopProc
        onExited: settle.restart()
    }

    Timer {
        id: settle
        interval: 600
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5000
        repeat: true
        running: !Store.lockSecure
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
