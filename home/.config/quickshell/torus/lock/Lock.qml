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
    readonly property string instance: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "none"
    property string buffer: ""
    property string attempt: ""
    property bool queued: false
    property string message: ""
    property bool busy: false
    property int fails: 0
    property string layout: ""
    property bool awake: true
    property bool releasing: false

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
            console.warn("lock: PAM timed out")
            pam.abort()
            root.busy = false
            root.attempt = ""
            root.message = "authentication timed out, try again"
        }
    }

    function submit() {
        if (buffer === "")
            return
        if (busy) {
            queued = true
            return
        }
        attempt = buffer
        buffer = ""
        queued = false
        busy = true
        message = ""
        console.info("lock: checking password")
        if (!pam.start()) {
            busy = false
            buffer = attempt
            attempt = ""
            message = "PAM did not start"
            console.warn("lock: PAM did not start")
        }
    }

    function failed(text) {
        busy = false
        attempt = ""
        fails++
        message = text
        if (queued)
            Qt.callLater(submit)
    }

    Connections {
        target: Store
        function onLockedChanged() {
            if (!Store.locked) {
                sessionLock.locked = false
                return
            }
            root.releasing = false
            fallback.armed = true
            stacked.running = true
            root.poke()
            root.buffer = ""
            root.attempt = ""
            root.queued = false
            root.message = ""
            layoutProc.running = true
            marker.running = true
        }
    }

    // A marker left by another Hyprland instance (a TTY login outlived it) must not lock this one.
    Process {
        id: boot
        running: true
        command: ["sh", "-c", "[ -e \"$1/locked\" ] && { printf x; cat \"$1/locked\"; }", "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === "")
                    return
                const owner = text.slice(1).trim()
                if (owner === "" || owner === root.instance) {
                    Store.locked = true
                } else {
                    console.info("lock: ignoring a marker from another Hyprland instance")
                    cleanup.running = true
                }
            }
        }
    }

    Process {
        id: marker
        command: ["sh", "-c", "mkdir -p -m 700 \"$1\" && printf '%s\\n' \"$2\" > \"$1/locked\"", "sh", root.dir, root.instance]
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
        onPamMessage: {
            if (responseRequired)
                respond(root.attempt)
            else if (messageIsError && message !== "")
                root.message = message
        }
        onCompleted: result => {
            console.info("lock: PAM finished, " + PamResult.toString(result))
            if (result === PamResult.Success) {
                root.fails = 0
                root.message = ""
                // a hyprlock stacked under this lock gets the session back and never sees the keyboard again
                Quickshell.execDetached(["pkill", "-USR1", "-x", "hyprlock"])
                root.release()
                return
            }
            if (result === PamResult.MaxTries || root.fails >= 2)
                root.failed("too many tries, the account may be locked for a few minutes")
            else
                root.failed("wrong password")
        }
        onError: error => {
            console.warn("lock: PAM error " + PamError.toString(error))
            root.failed(PamError.toString(error))
        }
    }

    function release() {
        releasing = true
        watchdog.stop()
        fallback.armed = false
        Store.locked = false
        buffer = ""
        attempt = ""
        queued = false
        busy = false
        cleanup.running = true
    }

    // A lock on top of a running hyprlock never gets the keyboard back once hyprlock ends, so wait for it instead.
    Process {
        id: stacked
        command: ["pidof", "hyprlock"]
        onExited: code => {
            if (!Store.locked)
                return
            if (code === 0) {
                console.info("lock: hyprlock holds the session, waiting for it")
                fallback.running = true
                return
            }
            sessionLock.locked = true
            watchdog.restart()
        }
    }

    // Never unlocks: an unconfirmed lock hands over to hyprlock and the session stays locked.
    Timer {
        id: watchdog
        interval: 5000
        onTriggered: {
            if (!Store.locked || sessionLock.secure)
                return
            console.warn("lock: not confirmed after 5 s, starting hyprlock")
            fallback.running = true
        }
    }

    Process {
        id: fallback
        property bool armed: false
        command: ["sh", "-c", "if pidof hyprlock > /dev/null; then while pidof hyprlock > /dev/null; do sleep 0.5; done; exit 0; fi; exec hyprlock"]
        onExited: code => {
            if (code === 0 && armed && Store.locked && !sessionLock.secure)
                root.release()
        }
    }

    WlSessionLock {
        id: sessionLock
        onLockStateChanged: {
            if (locked || !Store.locked || root.releasing)
                return
            console.warn("lock: compositor ended the shell lock, handing over to hyprlock")
            fallback.running = true
        }
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
