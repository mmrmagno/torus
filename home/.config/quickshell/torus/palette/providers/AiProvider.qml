import QtQuick
import Quickshell
import qs
import qs.services

Provider {
    key: "ai"
    name: "Ask AI"
    glyph: "󰚩"
    prefix: "!"
    help: "ask the local model, answer in the AI sidebar"
    ranked: true

    function results(term, scoped) {
        return term === "" ? [] : [{ id: "ai", kind: "ask", glyph: "󰚩", title: "Ask: " + term, sub: "answer in the AI sidebar", enter: "ask", act: () => { Store.setOpen("ai", true); Ai.ask(term) } }]
    }
}
