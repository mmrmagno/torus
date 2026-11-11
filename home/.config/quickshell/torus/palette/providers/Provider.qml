import QtQuick
import Quickshell

Scope {
    property string key
    property string name
    property string section: name
    property string glyph: "󰍉"
    property string prefix: ""
    property string help: ""
    property bool inAll: false
    property bool secret: false
    property bool scoped: true
    property bool smart: false
    property bool ranked: false
    property bool owning: false
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/torus"
}
