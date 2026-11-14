pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    PersistentProperties {
        id: kept
        reloadableId: "torus-meeting"
        property bool active: false
        property bool manual: false
        property bool dndBefore: false
        property bool dndMine: false
        property bool joined: false
    }

    property bool autoOn: true
    property alias active: kept.active
    property alias manual: kept.manual
    property alias dndBefore: kept.dndBefore
    property alias dndMine: kept.dndMine
    property bool setting: false
    readonly property bool wanted: autoOn && InUse.mic && (InUse.cam || Island.sharing)

    property alias joined: kept.joined
    property bool micSeen: false

    function joinCall(url) {
        if (!/^https:\/\/(meet\.google\.com|teams\.(microsoft|live)\.com|([a-z0-9-]+\.)?zoom\.us)\//.test(url))
            return false
        Quickshell.execDetached(["torus-launch", "xdg-open", url])
        joined = true
        micSeen = false
        joinGuard.restart()
        if (!active)
            begin()
        return true
    }

    function setAuto(on) {
        autoOn = on
        autoFile.setText(on ? "on\n" : "off\n")
    }

    function startNow() {
        manual = true
        if (!active)
            begin()
    }

    function endNow() {
        manual = false
        joined = false
        stopTimer.stop()
        if (active)
            end()
    }

    function begin() {
        console.info("meeting: started, mic " + InUse.micApps.join(",") + ", camera " + InUse.camera.join(",") + (Island.sharing ? ", screen share" : ""))
        active = true
        dndBefore = Store.dnd
        dndMine = false
        setting = true
        Store.dnd = true
        setting = false
        Island.flash("notification", { summary: "Meeting: notifications held", body: manual ? "until you end the meeting in SUPER+Space" : "they wait until the call ends", app: "torus", icon: "notifications", image: "", cat: "meeting" }, 4000)
    }

    function end() {
        console.info("meeting: ended" + (dndMine ? ", keeping the DND you set" : ""))
        active = false
        if (!dndMine) {
            setting = true
            Store.dnd = dndBefore
            setting = false
        }
    }

    Component.onCompleted: if (active && !wanted && !manual && !joined) stopTimer.restart()

    onWantedChanged: {
        if (wanted) {
            stopTimer.stop()
            if (!active)
                startTimer.restart()
        } else {
            startTimer.stop()
            if (active && !manual && !joined)
                stopTimer.restart()
        }
    }

    Connections {
        target: Store
        function onDndChanged() {
            if (root.active && !root.setting)
                root.dndMine = true
        }
    }

    Connections {
        target: InUse
        function onMicChanged() {
            if (!root.joined)
                return
            if (InUse.mic) {
                root.micSeen = true
                callEnd.stop()
            } else if (root.micSeen) {
                callEnd.restart()
            }
        }
    }

    Timer {
        id: callEnd
        interval: 20000
        onTriggered: if (root.joined && !InUse.mic) {
            root.joined = false
            if (root.active && !root.manual)
                root.end()
        }
    }

    Timer {
        id: joinGuard
        interval: 900000
        onTriggered: if (root.joined && !root.micSeen) {
            root.joined = false
            if (root.active && !root.manual)
                root.end()
        }
    }

    Timer {
        id: startTimer
        interval: 8000
        onTriggered: if (root.wanted && !root.active) root.begin()
    }

    Timer {
        id: stopTimer
        interval: 20000
        onTriggered: if (!root.wanted && root.active && !root.manual) root.end()
    }

    FileView {
        id: autoFile
        path: Store.stateDir + "/meeting-auto"
        blockLoading: true
        printErrors: false
        onLoaded: root.autoOn = text().trim() !== "off"
    }
}
