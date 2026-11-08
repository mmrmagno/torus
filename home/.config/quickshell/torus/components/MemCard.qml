import QtQuick
import qs
import qs.services

Column {
    spacing: 10
    width: 280

    Row {
        spacing: 10
        Text { text: SysStats.memUsed.toFixed(1) + "G"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: 26; font.weight: Font.Bold }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "of " + SysStats.memTotal.toFixed(1) + " GiB in use"; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: 11 }
    }

    Meter { width: 280; label: "Used"; value: Math.round(SysStats.memPercent) + "%"; fraction: SysStats.memPercent / 100 }
    Meter { width: 280; label: "Cache"; value: SysStats.memCached.toFixed(1) + " GiB"; fraction: SysStats.memCached / SysStats.memTotal; tint: Theme.teal }
    Meter {
        width: 280
        visible: SysStats.swapTotal > 0
        label: "Swap"
        value: SysStats.swapUsed.toFixed(1) + " / " + SysStats.swapTotal.toFixed(1) + " GiB"
        fraction: SysStats.swapTotal > 0 ? SysStats.swapUsed / SysStats.swapTotal : 0
        tint: Theme.peach
    }

    TopProcs { sort: "mem" }
}
