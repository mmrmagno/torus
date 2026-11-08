import QtQuick
import qs
import qs.services

Column {
    spacing: 10
    width: 280

    Row {
        spacing: 10
        Text { text: Math.round(SysStats.cpu) + "%"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: 26; font.weight: Font.Bold }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: "CPU" + (SysStats.cpuMhz > 0 ? "  " + (SysStats.cpuMhz / 1000).toFixed(2) + " GHz" : ""); color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: 11 }
            Text { text: "load " + SysStats.load; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: 11 }
        }
    }

    Row {
        spacing: 2
        height: 34
        Repeater {
            model: SysStats.cores
            Rectangle {
                required property real modelData
                width: Math.max(4, Math.floor((280 - 2 * (SysStats.cores.length - 1)) / Math.max(1, SysStats.cores.length)))
                height: 34
                radius: 2
                color: Theme.surface0
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(2, parent.height * modelData / 100)
                    radius: 2
                    color: modelData > 85 ? Theme.red : modelData > 50 ? Theme.peach : Theme.accent
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    Meter {
        width: 280
        label: "Temperature"
        value: SysStats.cpuTemp >= 0 ? SysStats.cpuTemp + "°C" : "--"
        fraction: SysStats.cpuTemp / 100
        tint: SysStats.cpuTemp >= 80 ? Theme.red : Theme.sapphire
    }

    TopProcs { sort: "cpu" }
}
