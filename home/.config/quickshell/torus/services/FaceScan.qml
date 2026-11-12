pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property string state: "idle"
    property string reason: ""
    property int scans: 0

    function hear(line) {
        const l = line.trim()
        if (l === "")
            return
        if (/^Attempting facial authentication/i.test(l)) {
            reason = ""
            state = "scan"
            scans++
            done.stop()
            giveUp.restart()
        } else if (/^Login approved/i.test(l)) {
            state = "ok"
            Store.sound("unlock")
            giveUp.stop()
            done.restart()
        } else if (/^Failure/i.test(l)) {
            reason = /dark/i.test(l) ? "too dark" : (/timeout/i.test(l) ? "no match" : "not recognized")
            state = "fail"
            Store.sound("error")
            giveUp.stop()
            done.restart()
        }
    }

    Process {
        id: follow
        running: true
        command: ["journalctl", "-f", "-n", "0", "-o", "cat", "-t", "pam_howdy"]
        stdout: SplitParser { onRead: line => root.hear(line) }
        onExited: retry.restart()
    }

    Timer {
        id: retry
        interval: 30000
        onTriggered: follow.running = true
    }

    Timer {
        id: done
        interval: 1600
        onTriggered: root.state = "idle"
    }

    Timer {
        id: giveUp
        interval: 12000
        onTriggered: root.state = "idle"
    }
}
