pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property var result: ({})
    property var config: ({ home: "", work: "" })
    property bool reversed: false
    property bool again: false
    readonly property bool busy: fetch.running
    readonly property bool opened: Store.isOpen("dashboard")
    readonly property bool configured: config.home !== "" && config.work !== ""
    readonly property var connections: result.connections || []

    Component.onCompleted: {
        loadConfig()
        if (opened)
            refresh()
    }

    onOpenedChanged: {
        if (!opened)
            return
        reversed = false
        loadConfig()
        refresh()
    }

    function refresh() {
        if (fetch.running) {
            again = true
            return
        }
        fetch.command = reversed ? ["torus-commute", "fetch", "--reverse"] : ["torus-commute", "fetch"]
        fetch.running = true
    }

    function swap() {
        reversed = !reversed
        result = Object.assign({}, result, { connections: [] })
        refresh()
    }

    function loadConfig() {
        if (!reader.running)
            reader.running = true
    }

    function save(home, work) {
        saver.payload = JSON.stringify({ home: home, work: work })
        saver.running = true
    }

    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.result = JSON.parse(text)
                } catch (e) {
                    root.result = { ok: false, configured: true, message: "could not read the timetable" }
                }
            }
        }
        onExited: {
            if (root.again) {
                root.again = false
                Qt.callLater(root.refresh)
            }
        }
    }

    Process {
        id: reader
        command: ["torus-commute", "config"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    root.config = { home: d.home || "", work: d.work || "" }
                } catch (e) {}
            }
        }
    }

    Process {
        id: saver
        property string payload: ""
        command: ["torus-commute", "save"]
        stdinEnabled: true
        onStarted: {
            write(payload)
            stdinEnabled = false
        }
        onExited: {
            stdinEnabled = true
            root.loadConfig()
            root.refresh()
        }
    }

    property bool alertMuted: false
    property bool alertsOn: false

    function muteToday(muted) {
        Quickshell.execDetached(["torus-commute", "alert", muted ? "mute" : "unmute"])
        alertMuted = muted
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.configured
        triggeredOnStart: true
        onTriggered: {
            if (checker.running || notifier.running)
                return
            checker.command = Store.dnd ? ["torus-commute", "alert", "status"] : ["torus-commute", "alert"]
            checker.running = true
        }
    }

    Process {
        id: checker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    root.alertMuted = d.muted === true
                    root.alertsOn = Object.keys(d.slots || {}).length > 0
                    if (d.due) {
                        notifier.command = ["notify-send", "-a", "Commute", "-i", "train", "-A", "later=In 15 min", "-A", "mute=Not today", d.title, d.body]
                        notifier.running = true
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: notifier
        stdout: StdioCollector {
            onStreamFinished: {
                const pick = text.trim()
                if (pick === "later")
                    Quickshell.execDetached(["torus-commute", "alert", "snooze"])
                else if (pick === "mute")
                    root.muteToday(true)
            }
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.opened && root.configured
        onTriggered: root.refresh()
    }

    Timer {
        interval: 20000
        running: fetch.running
        onTriggered: {
            fetch.running = false
            root.result = Object.assign({}, root.result, { ok: false, message: "the timetable did not answer, try again" })
        }
    }
}
