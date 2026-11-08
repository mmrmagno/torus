pragma Singleton
import QtQuick
import Quickshell
import qs
import "../background/donut.mjs" as D

Singleton {
    readonly property int w: D.W
    readonly property int h: D.H
    readonly property string chars: D.CHARS
    readonly property real speedA: 1.68
    readonly property real speedB: 0.72
    property int ticks: 0
    readonly property var colors: Object.keys(Theme.c).length > 0 ? D.ramp(Theme.c) : []
}
