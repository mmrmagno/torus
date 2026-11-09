import QtQuick
import qs
import qs.services

Column {
    spacing: Theme.sp5
    width: 280

    Row {
        spacing: Theme.sp5
        Text { text: (SysStats.gpuBusy >= 0 ? SysStats.gpuBusy : "--") + "%"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsHead; font.weight: Font.Bold }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: "GPU" + (SysStats.gpuMhz > 0 ? "  " + SysStats.gpuMhz + " MHz" : ""); color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
            Text { text: SysStats.gpuWatts >= 0 ? SysStats.gpuWatts + " W" : ""; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: Theme.fsSm }
        }
    }

    Meter {
        width: 280
        visible: SysStats.vramTotal > 0
        label: "VRAM"
        value: SysStats.vramUsed.toFixed(1) + " / " + SysStats.vramTotal.toFixed(0) + " GiB"
        fraction: SysStats.vramTotal > 0 ? SysStats.vramUsed / SysStats.vramTotal : 0
        tint: Theme.teal
    }
    Meter {
        width: 280
        label: "Edge / hotspot"
        value: (SysStats.gpuTemp >= 0 ? SysStats.gpuTemp + "°C" : "--") + (SysStats.gpuHotspot >= 0 ? " / " + SysStats.gpuHotspot + "°C" : "")
        fraction: Math.max(SysStats.gpuTemp, SysStats.gpuHotspot) / 110
        tint: SysStats.gpuHotspot >= 95 ? Theme.red : Theme.sapphire
    }
}
