import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

ColumnLayout {
    id: feel

    readonly property var soundNames: ({ open: "Panels", lock: "Lock", notify: "Notifications", device: "Devices", tick: "Volume ticks", record: "Recording", delete: "Delete", error: "Errors" })
    readonly property var soundPreview: ({ open: "open", lock: "unlock", notify: "notify", device: "device-in", tick: "tick", record: "record-start", delete: "delete", error: "error" })
    readonly property var islandNames: ({ music: "Music", volume: "Volume", notifications: "Notifications", devices: "Devices", battery: "Battery", meeting: "Meetings" })
    readonly property var panelNames: ({ dashboard: "Dashboard", network: "Network", updates: "Updates", center: "Notifications", theme: "Theme studio", capture: "Capture", session: "Session", ocr: "Text from picture", processes: "Processes" })

    Layout.fillWidth: true
    spacing: Theme.sp5

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Theme.sp6
        rowSpacing: Theme.sp5

        Text { text: "Animation speed"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
        ValueSlider { from: 0.5; to: 1.5; step: 0.05; value: Feel.speed; suffix: "×"; onMoved: v => Feel.set("speed", v) }

        Text { text: "Reduce motion"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
        RowLayout {
            spacing: Theme.sp4
            Toggle { checked: Feel.reduceMotion; onToggled: value => Feel.set("reduceMotion", value) }
            Text { text: "panels appear without moving (windows follow the preset above)"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
        }

        Text { text: "Text size"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
        RowLayout {
            spacing: Theme.sp5
            Segmented {
                options: ["0.9", "1", "1.15"]
                labels: ["Compact", "Normal", "Large"]
                current: String(Math.round(Feel.textScale * 100) / 100)
                onPicked: value => Feel.set("textScale", Number(value))
            }
            ValueSlider { Layout.fillWidth: true; from: 0.85; to: 1.3; step: 0.05; value: Feel.textScale; suffix: "×"; onMoved: v => Feel.set("textScale", v) }
        }

        Text { text: "Corner radius"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
        ValueSlider { from: 0; to: 1.6; step: 0.1; value: Feel.radius; suffix: "×"; onMoved: v => Feel.set("radius", v) }

        Text { text: "Glass"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
        ValueSlider { from: 0; to: 2; step: 0.1; value: Feel.glass; suffix: "×"; onMoved: v => Feel.set("glass", v) }

        Text { text: "On battery"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
        RowLayout {
            spacing: Theme.sp4
            Segmented { options: ["calm", "full"]; labels: ["Calm", "Full"]; current: Calm.mode; onPicked: value => Calm.setMode(value) }
            Text { text: Calm.onBattery ? (Calm.active ? "calm now: wallpaper resting, 60 Hz, lighter blur" : "full power on battery") : "on AC, nothing changes"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
        }

        Text { text: "Lock screen"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
        RowLayout {
            spacing: Theme.sp4
            Segmented {
                id: lockPick
                property string style: "torus"
                options: ["torus", "marc-os", "sf_marc"]
                labels: ["torus", "marc-os", "sf_marc"]
                current: lockPick.style
                onPicked: value => {
                    lockPick.style = value
                    Quickshell.execDetached(["torus-lockstyle", value])
                }
                Process {
                    running: Store.isOpen("theme")
                    command: ["torus-lockstyle", "get"]
                    stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") lockPick.style = text.trim() }
                }
            }
            Text { text: lockPick.style === "torus" ? "the shell's own lock, with face scan" : "hyprlock layout"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
        }
    }

    Text { text: "PANELS"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2; Layout.topMargin: Theme.sp3 }
    Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "A panel that follows focus moves to the screen you switch to; one that stays keeps to the screen it opened on."; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Theme.sp7
        rowSpacing: Theme.sp3
        Repeater {
            model: Feel.panels
            RowLayout {
                id: prow
                required property string modelData
                spacing: Theme.sp4
                Text { Layout.preferredWidth: 130; Layout.maximumWidth: 130; text: feel.panelNames[prow.modelData] || prow.modelData; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd; elide: Text.ElideRight }
                Segmented {
                    options: ["follow", "stay"]
                    labels: ["Follows", "Stays"]
                    current: Feel.stays(prow.modelData) ? "stay" : "follow"
                    onPicked: value => Feel.toggleIn("stay", prow.modelData, value === "stay")
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp6
        Text { text: "Follow delay"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
        ValueSlider { from: 0; to: 1500; step: 50; decimals: 0; value: Feel.followDelay; suffix: " ms"; onMoved: v => Feel.set("followDelay", v) }
    }

    Text { text: "SOUNDS"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2; Layout.topMargin: Theme.sp3 }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp6
        Toggle { checked: Store.sounds; onToggled: value => Store.setSounds(value) }
        Text { text: "UI sounds"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
        ValueSlider { enabled: Store.sounds; opacity: Store.sounds ? 1 : 0.5; from: 0; to: 1.5; step: 0.05; value: Feel.soundVolume; suffix: "×"; onMoved: v => Feel.set("soundVolume", v) }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: Theme.sp6
        rowSpacing: Theme.sp3
        opacity: Store.sounds ? 1 : 0.5
        Repeater {
            model: Feel.soundEvents
            RowLayout {
                id: srow
                required property string modelData
                spacing: Theme.sp3
                Toggle { checked: Feel.soundOn(srow.modelData); onToggled: value => Feel.toggleIn("soundsOff", srow.modelData, !value) }
                Text { text: feel.soundNames[srow.modelData]; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                Text {
                    text: "󰐊"
                    color: playHover.hovered ? Theme.accent : Theme.overlay
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsLg
                    HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Quickshell.execDetached(["torus-sound", "preview", feel.soundPreview[srow.modelData], String(Feel.soundVolume)]) }
                }
            }
        }
    }

    Text { text: "ISLAND"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2; Layout.topMargin: Theme.sp3 }
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: Theme.sp6
        rowSpacing: Theme.sp3
        Repeater {
            model: Feel.islandEvents
            RowLayout {
                id: irow
                required property string modelData
                spacing: Theme.sp3
                Toggle { checked: Feel.islandOn(irow.modelData); onToggled: value => Feel.toggleIn("islandOff", irow.modelData, !value) }
                Text { text: feel.islandNames[irow.modelData]; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp6
        Text { text: "Shown for"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
        ValueSlider { from: 0.8; to: 6; step: 0.2; decimals: 1; value: Feel.islandSeconds; suffix: " s"; onMoved: v => Feel.set("islandSeconds", v) }
    }
    PanelButton { icon: "󰑓"; label: "Reset feel to defaults"; implicitHeight: 30; onClicked: Feel.reset() }
}
