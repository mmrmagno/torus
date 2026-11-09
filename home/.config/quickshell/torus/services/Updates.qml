pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int count: -1
    property var packages: []
    property var news: []
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

    function update() {
        Quickshell.execDetached(["kitty", "--title", "torus-update", "-e", "sh", "-c", "yay -Syu; echo; read -n1 -p 'done, press a key'"])
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

    Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.check()
            root.fetchNews()
        }
    }
}
