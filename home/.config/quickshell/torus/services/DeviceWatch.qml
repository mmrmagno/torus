pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property var block: ({})
    property real startedAt: Date.now()
    property var lastSeen: ({})

    function kind(ifaces) {
        const i = ifaces || ""
        if (i.includes(":030101:"))
            return ["󰌌", "Keyboard"]
        if (i.includes(":030102:"))
            return ["󰍽", "Mouse"]
        if (/:08\d{4}:/.test(i))
            return ["󰋊", "Drive"]
        if (/:0e\d{4}:/.test(i))
            return ["󰄀", "Camera"]
        if (/:01\d{4}:/.test(i))
            return ["󰋋", "Audio"]
        if (/:03\d{4}:/.test(i))
            return ["󰊴", "Controller"]
        return ["󰕓", "Device"]
    }

    function emit(b) {
        console.info("devices: " + b.ACTION + " " + (b.DEVTYPE || "?") + " " + (b.ID_MODEL_FROM_DATABASE || b.ID_MODEL || "?"))
        if (b.ACTION !== "add" && b.ACTION !== "remove")
            return
        if (b.DEVTYPE !== "usb_device" || (b.ID_USB_INTERFACES || "").startsWith(":09") || /hub/i.test(b.ID_MODEL || ""))
            return
        if (Date.now() - startedAt < 4000)
            return
        const key = b.ACTION + (b.DEVPATH || "")
        if (Date.now() - (lastSeen[key] || 0) < 1500)
            return
        const seen = Object.assign({}, lastSeen)
        seen[key] = Date.now()
        lastSeen = seen
        const k = kind(b.ID_USB_INTERFACES)
        const name = (b.ID_MODEL_FROM_DATABASE || (b.ID_MODEL || "").replace(/_/g, " ") || k[1]).trim()
        Island.flash("osd", { icon: k[0], label: name + (b.ACTION === "add" ? " connected" : " removed"), value: -1 }, 2200)
        Store.sound(b.ACTION === "add" ? "device-in" : "device-out")
    }

    Process {
        id: mon
        running: true
        command: ["udevadm", "monitor", "--udev", "--property", "--subsystem-match=usb/usb_device"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line.startsWith("UDEV") || (line.startsWith("ACTION=") && root.block.ACTION))
                    root.flush()
                const i = line.indexOf("=")
                if (i > 0) {
                    const b = root.block
                    b[line.slice(0, i)] = line.slice(i + 1)
                    root.block = b
                    settle.restart()
                }
            }
        }
        onExited: restart.start()
    }

    function flush() {
        settle.stop()
        if (block.ACTION)
            emit(block)
        block = ({})
    }

    Timer {
        id: settle
        interval: 200
        onTriggered: root.flush()
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: mon.running = true
    }
}
