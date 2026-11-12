pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property string url: "http://127.0.0.1:11434"
    property bool remote: false
    property bool chosen: false
    property string status: "unknown"
    property var models: []
    property string model: ""
    property var messages: []
    property bool busy: false
    property string error: ""
    property bool stopping: false
    property bool pending: false

    function refresh() {
        tags.running = true
    }

    function pick(name) {
        model = name
        chosen = true
        modelFile.setText(name + "\n")
    }

    function cycleModel() {
        if (models.length > 0)
            pick(models[(models.indexOf(model) + 1) % models.length])
    }

    function reset() {
        stop()
        pending = false
        messages = []
        busy = false
        error = ""
    }

    function explain() {
        if (!grab.running)
            grab.running = true
    }

    function summarize(lines) {
        if (lines.length === 0)
            return
        Store.setOpen("ai", true)
        ask("Summarize these notifications in at most four short bullets, most important first. Say who wants something from me.\n\n" + lines.join("\n"))
    }

    Process {
        id: grab
        command: ["sh", "-c", "t=$(timeout 2 wl-paste -p -n 2>/dev/null | head -c 6000); if [ -n \"$(printf %s \"$t\" | tr -d '[:space:]')\" ]; then printf 'sel\\n%s' \"$t\"; else f=${XDG_RUNTIME_DIR:-/tmp}/torus-last-error; [ -s \"$f\" ] && printf 'cmd\\n' && head -c 2000 \"$f\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kind = text.slice(0, 4)
                const body = text.slice(4).trim()
                if (body.trim() === "") {
                    root.error = "select some text first (or run a failing command in a terminal)"
                    Store.setOpen("ai", true)
                    return
                }
                Store.setOpen("ai", true)
                root.ask(kind === "sel\n"
                    ? "Explain this briefly. If it is an error, say what causes it and how to fix it.\n\n" + body
                    : "This shell command just failed. Explain briefly why it might fail and how to fix it.\n\n" + body)
            }
        }
    }

    function ask(text) {
        if (busy || text.trim() === "" || model === "")
            return
        error = ""
        messages = messages.concat([{ role: "user", content: text }, { role: "assistant", content: "" }])
        busy = true
        if (chat.running && !stopping) {
            pending = true
            stopping = true
            chat.running = false
        } else if (stopping) {
            pending = true
        } else {
            chat.running = true
        }
    }

    function stop() {
        if (!chat.running)
            return
        stopping = true
        chat.running = false
    }

    function append(part) {
        const m = messages.slice()
        const last = Object.assign({}, m[m.length - 1])
        last.content += part
        m[m.length - 1] = last
        messages = m
    }

    Process {
        id: tags
        command: ["torus-ai-host"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    if (j.status !== "online")
                        throw new Error("offline")
                    const names = j.models
                    root.url = j.url
                    root.remote = j.remote === true
                    root.models = names
                    if (!root.chosen || names.indexOf(root.model) < 0)
                        root.model = j.pick || (names.length > 0 ? names[0] : "")
                    root.status = "online"
                } catch (e) {
                    root.models = []
                    root.status = "offline"
                }
            }
        }
        onExited: code => {
            if (code !== 0) {
                root.models = []
                root.status = "offline"
            }
        }
    }

    Process {
        id: chat
        command: ["curl", "-sN", "--max-time", "600", "-H", "Content-Type: application/json", "--data-binary", "@-", root.url + "/api/chat"]
        stdinEnabled: true
        onStarted: {
            const history = root.messages.slice(0, -1).map(m => ({ role: m.role, content: m.content }))
            write(JSON.stringify({ model: root.model, messages: history, stream: true }))
            stdinEnabled = false
        }
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() === "")
                    return
                try {
                    const j = JSON.parse(line)
                    if (j.error)
                        root.error = j.error
                    else if (j.message && j.message.content)
                        root.append(j.message.content)
                } catch (e) {
                    root.error = "bad reply from ollama"
                }
            }
        }
        onExited: code => {
            stdinEnabled = true
            if (root.stopping) {
                root.stopping = false
                if (root.pending) {
                    root.pending = false
                    running = true
                } else {
                    root.busy = false
                }
                return
            }
            root.busy = false
            if (code !== 0 && root.error === "")
                root.error = code === 7 ? "ollama is not running" : "request stopped"
        }
    }

    FileView {
        id: modelFile
        path: Store.stateDir + "/ai-model"
        blockLoading: true
        printErrors: false
        onLoaded: {
            root.model = text().trim()
            root.chosen = root.model !== ""
        }
    }
}
