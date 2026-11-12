import QtQuick
import Quickshell
import qs
import qs.services

Provider {
    key: "ai"
    name: "Ask AI"
    glyph: "󰚩"
    prefix: "!"
    help: "ask the local model, answer in the AI sidebar; empty or Ctrl+Enter explains the selected text"
    ranked: true

    readonly property var explainRow: ({ label: "explain the selection", act: () => Ai.explain() })

    function results(term, scoped) {
        if (term === "")
            return scoped ? [{ id: "ai-explain", kind: "ask", glyph: "󰚩", title: "Explain the selected text", sub: "or the last failed terminal command, answer in the AI sidebar" + (Ai.remote ? " (desktop model)" : ""), enter: "explain", act: () => Ai.explain() }] : []
        return [{ id: "ai", kind: "ask", glyph: "󰚩", title: "Ask: " + term, sub: "answer in the AI sidebar, Ctrl ↵ explains the selection instead", enter: "ask", act: () => { Store.setOpen("ai", true); Ai.ask(term) }, ctrl: explainRow }]
    }
}
