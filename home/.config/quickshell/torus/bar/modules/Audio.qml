import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

import Quickshell.Services.Pipewire

Chip {
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink && sink.audio
    icon: !ready || sink.audio.muted ? "󰝟" : "󰕾"
    iconColor: ready && sink.audio.muted ? Theme.red : Theme.accent
    label: ready ? Math.round(sink.audio.volume * 100) : "--"
    onClicked: if (ready) sink.audio.muted = !sink.audio.muted
    onRightClicked: Quickshell.execDetached(["pavucontrol"])
    onScrolled: delta => {
        if (ready)
            sink.audio.volume = Math.max(0, Math.min(1.5, sink.audio.volume + delta * 0.05))
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
}
