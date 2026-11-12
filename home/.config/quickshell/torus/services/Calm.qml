pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs

Singleton {
    id: root

    property string mode: "calm"
    property bool forced: false
    property bool ready: false
    readonly property bool onBattery: UPower.onBattery
    readonly property bool active: (onBattery || forced) && mode === "calm"

    function setMode(m) {
        if (m !== "calm" && m !== "full")
            return
        mode = m
        modeFile.setText(m + "\n")
    }

    onActiveChanged: if (ready) apply()

    function apply() {
        Quickshell.execDetached(["torus-calm", active ? "on" : "off"])
    }

    FileView {
        id: modeFile
        path: Store.stateDir + "/battery-mode"
        blockLoading: true
        printErrors: false
        onLoaded: root.mode = text().trim() === "full" ? "full" : "calm"
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: {
            root.ready = true
            root.apply()
        }
    }
}
