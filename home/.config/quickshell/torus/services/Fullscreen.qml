pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property var full: ({})
    readonly property bool any: Object.keys(full).some(k => full[k] === true)

    function isFull(name) {
        return full[name] === true
    }

    function refresh() {
        if (!proc.running)
            proc.running = true
    }

    Process {
        id: proc
        command: ["sh", "-c", "[ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ] || export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t \"$XDG_RUNTIME_DIR/hypr\" | head -1); printf '{\"m\":'; hyprctl -j monitors; printf ',\"w\":'; hyprctl -j workspaces; printf '}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    const ws = {}
                    for (const w of j.w)
                        ws[w.id] = w.hasfullscreen === true
                    const out = {}
                    for (const m of j.m)
                        out[m.name] = ws[m.activeWorkspace.id] === true
                    root.full = out
                } catch (e) {
                    console.warn("torus: fullscreen state", e)
                }
            }
        }
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["fullscreen", "closewindow", "openwindow", "workspace", "workspacev2", "focusedmon", "focusedmonv2", "movewindow", "movewindowv2", "moveworkspace", "moveworkspacev2", "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2", "monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "changefloatingmode"].indexOf(event.name) >= 0)
                debounce.restart()
        }
    }
}
