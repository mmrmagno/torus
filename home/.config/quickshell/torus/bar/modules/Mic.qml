import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

import Quickshell.Services.Pipewire

Chip {
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool ready: source && source.audio
    icon: !ready || source.audio.muted ? "󰍭" : "󰍬"
    iconColor: ready && source.audio.muted ? Theme.red : Theme.accent
    onClicked: if (ready) source.audio.muted = !source.audio.muted
    onScrolled: delta => {
        if (ready)
            source.audio.volume = Math.max(0, Math.min(1.5, source.audio.volume + delta * 0.05))
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSource]
    }
}
