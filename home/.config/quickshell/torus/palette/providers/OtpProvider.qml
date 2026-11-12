import QtQuick
import Quickshell
import qs
import qs.services

Provider {
    key: "otp"
    name: "Codes"
    glyph: "󰌆"
    help: "a one-time code from the last 2 minutes, Enter copies it (never stored)"
    inAll: true
    scoped: false

    function results(term, scoped) {
        const o = Notifs.otp
        if (!o.code || Date.now() > o.until)
            return []
        return [{ id: "otp", kind: "action", glyph: "󰌆", title: "Copy " + o.code, sub: "one-time code from " + (o.app || "a notification") + ", clears from the clipboard in 90 s",
                  keys: "code otp 2fa verification " + o.app, enter: "copy", keep: true, act: () => { Notifs.copyOtp(o.code); Store.setOpen("palette", false) } }]
    }
}
