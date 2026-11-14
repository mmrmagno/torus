pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs

Singleton {
    id: root

    property var known: ({})
    property real startedAt: Date.now()
    readonly property int low: 20
    readonly property int rearm: 25
    property string last: ""

    function kindOf(d) {
        if (!d || d.isLaptopBattery)
            return ""
        if (d.type === UPowerDeviceType.GamingInput)
            return "controller"
        if (d.type === UPowerDeviceType.Headset || d.type === UPowerDeviceType.Headphones)
            return "headphones"
        return ""
    }

    function icon(kind) {
        return kind === "controller" ? "󰊴" : "󰋋"
    }

    function observe(key, model, kind, pct) {
        if (!kind || pct < 0)
            return
        const k = Object.assign({}, known)
        const name = model || (kind === "controller" ? "Controller" : "Headphones")
        const was = k[key]
        if (!was) {
            k[key] = { pct: pct, warned: pct < low }
            known = k
            if (Date.now() - startedAt > 5000) {
                last = "connect:" + name + ":" + pct
                Island.flash("osd", { icon: icon(kind), label: name + "  ·  " + pct + "%", value: pct / 100, cat: "devices" }, 2600)
            }
            if (pct < low)
                warn(name, kind, pct)
            return
        }
        const w = { pct: pct, warned: was.warned }
        if (pct < low && !was.warned) {
            w.warned = true
            warn(name, kind, pct)
        } else if (pct >= rearm) {
            w.warned = false
        }
        k[key] = w
        known = k
    }

    function warn(name, kind, pct) {
        last = "low:" + name + ":" + pct
        Island.flash("notification", { summary: name + " battery low", body: pct + "% left", app: "torus", icon: kind === "controller" ? "input-gaming" : "audio-headphones", image: "", cat: "devices" }, 6000)
    }

    function forget(key) {
        const k = Object.assign({}, known)
        delete k[key]
        known = k
    }

    Instantiator {
        model: UPower.devices
        delegate: QtObject {
            id: watch
            required property var modelData
            readonly property string kind: root.kindOf(modelData)
            readonly property int pct: modelData && modelData.isPresent ? Math.round(modelData.percentage * 100) : -1
            readonly property string key: modelData ? modelData.nativePath || modelData.model : ""
            onPctChanged: root.observe(watch.key, watch.modelData.model, watch.kind, watch.pct)
            Component.onCompleted: root.observe(watch.key, watch.modelData.model, watch.kind, watch.pct)
            Component.onDestruction: root.forget(watch.key)
        }
    }
}
