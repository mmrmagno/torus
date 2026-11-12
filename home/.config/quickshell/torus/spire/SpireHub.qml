import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    readonly property var d: Spire.data
    readonly property var badKs: (d.kustomizations || []).filter(k => !k.ready)
    readonly property var badHr: (d.helmreleases || []).filter(h => !h.ready)

    function count(n, word) {
        return n + " " + word + (n === 1 ? "" : "s")
    }

    function browse(url) {
        Quickshell.execDetached(["sh", "-c", "command -v firefox > /dev/null && exec firefox \"$1\" || exec xdg-open \"$1\"", "sh", url])
    }

    screen: Store.screenFor("homelab")
    visible: Store.isOpen("homelab") || motion.leaving
    anchors.top: true
    margins.top: Store.barGap
    implicitWidth: Math.floor(Math.min(980, (screen ? screen.width : 1000) - 40))
    implicitHeight: Store.panelRoom(screen, 20)
    mask: Region { item: hubFrame }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("homelab") && !Store.moving ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: Store.isOpen("homelab") && root.backingWindowVisible
        windows: [root]
        onCleared: Store.setOpen("homelab", false)
    }

    Rectangle {
        id: hubFrame
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(body.implicitHeight + 40, root.implicitHeight)
        Behavior on height { enabled: root.visible; NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
        transformOrigin: Item.Top
        focus: true
        Keys.onEscapePressed: Store.setOpen("homelab", false)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_R) {
                Spire.refresh()
                event.accepted = true
            }
        }
        PanelMotion {
            id: motion
            target: hubFrame
            shown: Store.isOpen("homelab") && !Store.moving
        }
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: 20
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: body
                width: parent.width
                spacing: Theme.sp6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp5
                    Text { text: "󱃾"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 24 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { text: "Spire"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsTitle; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: !Spire.ok ? (root.d.reason || "checking…")
                                : (Spire.problems === 0 ? "all healthy" : Spire.problems + (Spire.problems === 1 ? " problem" : " problems"))
                                    + "  ·  " + (root.d.context || "") + "  ·  checked " + Spire.ago(root.d.at) + "  ·  R refreshes, read only"
                            color: !Spire.ok || Spire.problems > 0 ? Theme.peach : Theme.green
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSm
                        }
                    }
                    PanelButton { icon: "󰑐"; label: "Refresh"; onClicked: Spire.refresh() }
                    PanelButton {
                        icon: "󰕮"
                        label: "Grafana"
                        visible: (root.d.apps || []).some(a => /grafana/i.test(a.host))
                        onClicked: root.browse(((root.d.apps || []).find(a => /grafana/i.test(a.host)) || {}).url)
                    }
                }

                StatusRow {
                    visible: !Spire.ok
                    glyph: "󰋼"
                    tint: Theme.peach
                    title: root.d.reason === "no kubectl context" ? "kubectl has no context here" : (root.d.reason || "checking…")
                    sub: root.d.reason === "no kubectl context" ? "the shell does not see your shell's KUBECONFIG: add \"kubeconfig\" (and \"talosconfig\") paths to ~/.config/torus/spire.json" : "R refreshes"
                }

                Text { visible: Spire.ok; text: "CLUSTER"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2 }
                GridLayout {
                    Layout.fillWidth: true
                    columns: Math.max(1, Math.min(4, Math.floor(root.implicitWidth / 230)))
                    columnSpacing: Theme.sp5
                    rowSpacing: Theme.sp5
                    Repeater {
                        model: root.d.nodes || []
                        NodeCard { required property var modelData; node: modelData }
                    }
                }

                ColumnLayout {
                    visible: Spire.ok
                    Layout.fillWidth: true
                    spacing: 0
                    StatusRow {
                        glyph: root.badKs.length + root.badHr.length === 0 ? "󰄬" : "󰅚"
                        tint: root.badKs.length + root.badHr.length === 0 ? Theme.green : Theme.red
                        title: "Flux: " + root.count((root.d.kustomizations || []).length, "kustomization") + ", " + root.count((root.d.helmreleases || []).length, "Helm release")
                        sub: root.badKs.concat(root.badHr).map(x => x.ns + "/" + x.name + ": " + x.msg).join("  ·  ") || "all reconciled"
                    }
                    StatusRow {
                        glyph: (root.d.pods || []).length === 0 ? "󰄬" : "󰅚"
                        tint: (root.d.pods || []).length === 0 ? Theme.green : Theme.red
                        title: (root.d.pods || []).length === 0 ? "Pods: all running" : "Pods: " + root.d.pods.length + " unhealthy"
                        sub: (root.d.pods || []).slice(0, 4).map(p => p.ns + "/" + p.name + " " + p.why).join("  ·  ")
                    }
                    Repeater {
                        model: (root.d.events || []).slice(0, 4)
                        StatusRow {
                            required property var modelData
                            glyph: "󰀪"
                            tint: Theme.yellow
                            title: modelData.reason + "  ·  " + modelData.ns + " " + modelData.obj
                            sub: modelData.msg + "  ·  " + Spire.ago(modelData.at)
                        }
                    }
                }

                Text { text: "APPS"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2; visible: (root.d.apps || []).length > 0 }
                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.sp4
                    Repeater {
                        model: root.d.apps || []
                        PanelButton {
                            required property var modelData
                            icon: "󰖟"
                            label: modelData.host
                            onClicked: root.browse(modelData.url)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp6

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 0
                        Text { text: "TAILSCALE ROUTERS"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2 }
                        StatusRow {
                            visible: (root.d.tailscale || []).length === 0
                            glyph: "󰋼"
                            tint: Theme.overlay
                            title: "no routers listed"
                            sub: "add \"tailscale\": [\"ironclad\", \"regent\"] to ~/.config/torus/spire.json"
                        }
                        Repeater {
                            model: root.d.tailscale || []
                            StatusRow {
                                required property var modelData
                                glyph: /Running/.test(modelData.state) ? "󰄬" : "󰅚"
                                tint: /Running/.test(modelData.state) ? Theme.green : Theme.red
                                title: modelData.node + "  ·  " + modelData.state
                                sub: modelData.routes ? "routes " + modelData.routes : "no routes advertised"
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 0
                        Text { text: "REMOTE HANDS (AMT)"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2 }
                        StatusRow {
                            visible: Spire.amt.length === 0
                            glyph: "󰋼"
                            tint: Theme.overlay
                            title: "no AMT nodes listed"
                            sub: "add \"amt\": { \"<node>\": \"<ip>\" } to ~/.config/torus/spire.json"
                        }
                        Repeater {
                            model: Spire.amt
                            RowLayout {
                                id: amtRow
                                required property var modelData
                                Layout.fillWidth: true
                                StatusRow {
                                    glyph: amtRow.modelData.up ? "󰄬" : "󰅚"
                                    tint: amtRow.modelData.up ? Theme.green : Theme.red
                                    title: amtRow.modelData.node + (amtRow.modelData.up ? "  ·  reachable" : "  ·  not reachable")
                                    sub: "TCP 16993 from this workstation"
                                }
                                PanelButton { icon: "󰍹"; label: "Console"; implicitHeight: 30; onClicked: Quickshell.execDetached(["kitty", "--class", "torus-amt", "-e", "amt"]) }
                                PanelButton { icon: "󰖟"; label: "Web"; implicitHeight: 30; onClicked: root.browse(amtRow.modelData.web) }
                            }
                        }
                    }
                }

                Text { text: "BACKUPS"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2; visible: (root.d.backups || []).length > 0 }
                Repeater {
                    model: root.d.backups || []
                    StatusRow {
                        required property var modelData
                        readonly property real hours: modelData.last ? (Date.now() - Date.parse(modelData.last)) / 3600000 : 1e9
                        glyph: hours < 13 ? "󰄬" : "󰀪"
                        tint: hours < 13 ? Theme.green : Theme.yellow
                        title: modelData.ns + "/" + modelData.name + "  ·  last success " + Spire.ago(modelData.last)
                        sub: "schedule " + modelData.schedule
                    }
                }
            }
        }
    }
}
