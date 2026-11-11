import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    id: root

    function names(list) {
        return Array.from(new Set(list)).join(", ")
    }

    readonly property var micApps: InUse.micApps
    readonly property var camera: InUse.camera
    readonly property bool shown: micApps.length > 0 || camera.length > 0 || Meeting.active

    icon: [Meeting.active ? "󰤙" : "", camera.length > 0 ? "󰄀" : "", micApps.length > 0 ? "󰍬" : ""].filter(x => x !== "").join(" ")
    iconColor: Meeting.active ? Theme.red : Theme.peach
    tip: [
        Meeting.active ? "Meeting: notifications held " + (Meeting.manual ? "until you end it in SUPER+Space" : "until the call ends") : "",
        micApps.length > 0 ? "Microphone: " + names(micApps) : "",
        camera.length > 0 ? "Camera: " + names(camera) : "",
        !Meeting.active && Meeting.autoOn && micApps.length > 0 && camera.length === 0 ? "Meeting mode starts with a camera or a screen share" : ""
    ].filter(x => x !== "").join("\n")
}
