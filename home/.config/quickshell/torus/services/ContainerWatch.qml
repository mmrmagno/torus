pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property var list: []

    function refresh() {
        if (!proc.running)
            proc.running = true
    }

    function logs(c) {
        Quickshell.execDetached(["torus-launch", "kitty", "--title", c.name + " logs", "torus-containers", "logs", c.engine, c.id])
    }

    function restartProject(engine, project) {
        actProc.exec(["torus-containers", "restart-project", engine, project])
    }

    function act(c, what) {
        actProc.exec(["torus-containers", what, c.engine, c.id])
    }

    Process {
        id: proc
        command: ["torus-containers", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.list = text.split("\n").filter(l => l).map(l => {
                const f = l.split("\t")
                return { engine: f[0], id: f[1], name: f[2], image: f[3], status: f[4] || "", ports: f[5] || "", project: f[6] || "" }
            }).sort((a, b) => (a.project === "") - (b.project === "") || a.project.localeCompare(b.project) || a.name.localeCompare(b.name))
        }
    }

    Process {
        id: actProc
        onExited: settle.restart()
    }

    Timer {
        id: settle
        interval: 800
        onTriggered: root.refresh()
    }

    Timer {
        interval: 10000
        repeat: true
        running: !Store.lockSecure
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
