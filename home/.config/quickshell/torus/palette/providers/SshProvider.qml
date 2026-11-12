import QtQuick
import Quickshell
import Quickshell.Io

Provider {
    id: root
    key: "ssh"
    name: "SSH"
    glyph: "󰣀"
    prefix: "s "
    help: "hosts from ~/.ssh/config; Enter connects in kitty"
    inAll: true

    property var items: []

    function opened() {
        if (!proc.running)
            proc.running = true
    }

    function results(term, scoped) {
        return items
    }

    Process {
        id: proc
        command: ["torus-ssh-hosts"]
        stdout: StdioCollector {
            onStreamFinished: root.items = text.split("\n").filter(l => l).map(l => {
                const f = l.split("\t")
                const host = f[0], name = f[1] || "", user = f[2] || "", jump = f[3] || ""
                return {
                    id: "ssh:" + host, kind: "ssh", glyph: "󰣀", title: host,
                    sub: (user ? user + "@" : "") + (name || host) + (jump ? "  ·  via " + jump : ""), keys: name,
                    enter: "connect", act: () => Quickshell.execDetached(["torus-launch", "kitty", "--title", "ssh " + host, "ssh", host]),
                    ctrl: { label: "copy ssh command", act: () => Quickshell.execDetached(["wl-copy", "--", "ssh " + host]) },
                    alt: { label: "kitten ssh", act: () => Quickshell.execDetached(["torus-launch", "kitty", "--title", "ssh " + host, "kitten", "ssh", host]) }
                }
            })
        }
    }
}
