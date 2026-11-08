import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam
import qs
import qs.services

Scope {
    id: root

    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/torus-lock"
    property string buffer: ""
    property string message: ""
    property bool busy: false
    property int fails: 0
    property string layout: ""
    property bool awake: true

    function poke() {
        awake = true
        nap.restart()
    }

    Timer {
        id: nap
        interval: 30000
        onTriggered: root.awake = false
    }

    Timer {
        id: pamTimeout
        interval: 30000
        running: root.busy
        onTriggered: {
            pam.abort()
            root.busy = false
            root.buffer = ""
            root.message = "authentication timed out"
        }
    }

    function submit() {
        if (busy || buffer === "")
            return
        busy = true
        message = ""
        if (!pam.start()) {
            busy = false
            message = "PAM did not start"
        }
    }

    function finish() {
        message = ""
        fails = 0
        release()
    }

    Connections {
        target: Store
        function onLockedChanged() {
            sessionLock.locked = Store.locked
            if (!Store.locked)
                return
            watchdog.restart()
            root.poke()
            root.buffer = ""
            root.message = ""
            layoutProc.running = true
            marker.running = true
        }
    }

    Process {
        id: boot
        running: true
        command: ["test", "-e", root.dir + "/locked"]
        onExited: code => {
            if (code === 0)
                Store.locked = true
        }
    }

    Process {
        id: marker
        command: ["sh", "-c", "mkdir -p -m 700 \"$1\" && : > \"$1/locked\"", "sh", root.dir]
    }

    Process {
        id: cleanup
        command: ["sh", "-c", "rm -f \"$1\"/*.png \"$1/locked\"", "sh", root.dir]
    }

    Process {
        id: layoutProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards.find(k => k.main) || {}
                    root.layout = kb.active_keymap || ""
                } catch (e) {
                    root.layout = ""
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout" && Store.locked)
                layoutProc.running = true
        }
    }

    PamContext {
        id: pam
        config: "hyprlock"
        onResponseRequiredChanged: {
            if (responseRequired)
                respond(root.buffer)
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.finish()
                return
            }
            root.busy = false
            root.buffer = ""
            root.fails++
            root.message = result === PamResult.MaxTries ? "too many tries, wait a moment" : "wrong password"
        }
        onError: error => {
            root.busy = false
            root.buffer = ""
            root.message = PamError.toString(error)
        }
    }

    function release() {
        watchdog.stop()
        Store.locked = false
        root.buffer = ""
        root.busy = false
        cleanup.running = true
    }

    Timer {
        id: watchdog
        interval: 3000
        onTriggered: if (Store.locked && !sessionLock.secure) root.release()
    }

    WlSessionLock {
        id: sessionLock
        onLockStateChanged: if (!locked && Store.locked) root.release()
        onSecureStateChanged: {
            Store.lockSecure = secure
            if (secure)
                watchdog.stop()
        }
        WlSessionLockSurface {
            id: surface
            color: Theme.crust
            LockSurface {
                anchors.fill: parent
                lock: root
                screen: surface.screen
            }
        }
    }
}
