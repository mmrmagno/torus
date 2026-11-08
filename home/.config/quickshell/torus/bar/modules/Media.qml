import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

import Quickshell.Services.Mpris

Chip {
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    icon: player && player.isPlaying ? "󰏤" : "󰐊"
    tip: player ? (player.trackTitle || "") + (player.trackArtist ? "\n" + player.trackArtist : "") + "\nClick play/pause, scroll skip" : "Nothing playing"
    label: {
        if (!player)
            return "Music"
        const t = (player.trackTitle || "") + (player.trackArtist ? " · " + player.trackArtist : "")
        return t.length > 32 ? t.slice(0, 31) + "…" : t
    }
    onClicked: player ? player.togglePlaying() : null
    onScrolled: delta => player ? (delta > 0 ? player.next() : player.previous()) : null
}
