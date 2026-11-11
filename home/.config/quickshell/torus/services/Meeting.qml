pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property bool autoOn: true
    property bool active: false
    property bool manual: false
    property bool dndBefore: false
    property bool dndMine: false
    property bool setting: false
    readonly property bool wanted: autoOn && InUse.mic && (InUse.cam || Island.sharing)

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
        Island.flash("notification", { summary: "Meeting: notifications held", body: manual ? "until you end the meeting in SUPER+Space" : "they wait until the call ends", app: "torus", icon: "notifications", image: "" }, 4000)
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

    onWantedChanged: {
        if (wanted) {
            stopTimer.stop()
            if (!active)
                startTimer.restart()
        } else {
            startTimer.stop()
            if (active && !manual)
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
