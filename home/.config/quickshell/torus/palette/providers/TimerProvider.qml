import QtQuick
import Quickshell
import qs.services

Provider {
    key: "timer"
    name: "Timer"
    glyph: "󰔛"
    prefix: "t "
    help: "t 5, t 90s, t 1h, t 10m tea; a stopwatch"
    ranked: true

    function results(term, scoped) {
        const out = []
        const t = Timers.parse(term)
        if (Timers.running)
            out.push({ id: "tm:stop", kind: "action", glyph: "󰓛", title: "Stop " + (Timers.stopwatch ? "stopwatch" : "timer") + "  " + Timers.text, sub: Timers.label || "", enter: "stop", act: () => Timers.stop() })
        if (t)
            out.push({ id: "tm", kind: "action", glyph: "󰔛", title: "Timer " + (t.secs >= 3600 ? Math.floor(t.secs / 3600) + " h " : "") + (t.secs % 3600 >= 60 ? Math.floor(t.secs % 3600 / 60) + " min " : "") + (t.secs % 60 ? t.secs % 60 + " s" : "") + (t.label ? "  ·  " + t.label : ""), sub: "counts down in the island", enter: "start", act: () => Timers.start(t.secs, t.label) })
        if (term === "") {
            for (const m of [1, 3, 5, 10, 25]) {
                const mins = m
                out.push({ id: "tm" + m, kind: "action", glyph: "󰔛", title: "Timer " + m + " min", sub: "counts down in the island", enter: "start", act: () => Timers.start(mins * 60, "") })
            }
            out.push({ id: "tm:sw", kind: "action", glyph: "󱎫", title: "Stopwatch", sub: "counts up in the island, click pauses", enter: "start", act: () => Timers.startStopwatch() })
        } else if (!t) {
            out.push({ id: "tm:h", kind: "hint", glyph: "󰔛", title: "Try  t 5,  t 90s,  t 1h,  t 10m tea", sub: "minutes by default", act: () => {} })
        }
        return out
    }
}
