import QtQuick
import Quickshell
import qs.services

Provider {
    id: root
    key: "containers"
    name: "Containers"
    glyph: "󰡨"
    prefix: "c "
    help: "running docker and podman containers; Enter logs, Ctrl+Enter restart, Alt+Enter stop"

    function opened() {
        ContainerWatch.refresh()
    }

    function results(term, scoped) {
        if (ContainerWatch.list.length === 0)
            return [{ id: "ct:none", kind: "hint", glyph: "󰡨", title: "No containers running", sub: "docker or podman, whichever answers", act: () => {} }]
        return ContainerWatch.list.map(c => ({
            id: "ct:" + c.engine + ":" + c.name, kind: "container", glyph: "󰡨", title: c.name,
            sub: c.image + "  ·  " + c.status + (c.ports ? "  ·  " + c.ports : ""), keys: c.image, enter: "logs",
            act: () => ContainerWatch.logs(c),
            ctrl: { label: "restart", act: () => ContainerWatch.act(c, "restart") },
            alt: { label: "stop", act: () => ContainerWatch.act(c, "stop") }
        }))
    }
}
