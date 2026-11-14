pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int count: -1
    property var packages: []
    property var news: []
    property var torus: []
    property var torusInstalled: null
    property int torusUnsigned: 0
    property bool checking: false
    readonly property int unread: news.filter(n => n.state === "new").length

    function check() {
        if (proc.running)
            return
        checking = true
        proc.running = true
    }

    function fetchNews() {
        if (!newsProc.running)
            newsProc.running = true
    }

    function updateTorus() {
        Quickshell.execDetached(["torus-launch", "kitty", "--title", "torus-update", "-e", "sh", "-c", "torus update; echo; read -n1 -p 'done, press a key'"])
    }

    function update() {
        Quickshell.execDetached(["torus-launch", "kitty", "--title", "torus-update", "-e", "sh", "-c", "torus-updates upgrade; echo; read -n1 -p 'done, press a key'"])
    }

    Process {
        id: proc
        command: ["torus-updates", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.packages = text.split("\n").filter(l => l).map(l => {
                    const f = l.split("\t")
                    return { source: f[0], name: f[1], from: f[2], to: f[3] }
                })
                root.count = root.packages.length
                root.checking = false
            }
        }
    }

    Process {
        id: newsProc
        command: ["torus-updates", "news", "6"]
        stdout: StdioCollector {
            onStreamFinished: root.news = text.split("\n").filter(l => l).map(l => {
                const f = l.split("\t")
                return { state: f[0], date: f[1], title: f[2], link: f[3] }
            })
        }
    }

    Process {
        id: torusProc
        command: ["torus-updates", "torus", "20"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(l => l).map(l => {
                    const f = l.split("\t")
                    return { kind: f[0], hash: f[1], subject: f[2], date: f[3] }
                })
                root.torusInstalled = rows.find(r => r.kind === "installed") || null
                root.torus = rows.filter(r => r.kind === "new" || r.kind === "unsigned")
                root.torusUnsigned = rows.filter(r => r.kind === "unsigned").length
            }
        }
    }

    Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.check()
            root.fetchNews()
            if (!torusProc.running)
                torusProc.running = true
        }
    }
}
