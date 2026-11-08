import QtQuick
import Quickshell

Scope {
    id: root

    required property var screen

    Corner { screen: root.screen; screenName: root.screen.name; atTop: true; atLeft: true }
    Corner { screen: root.screen; screenName: root.screen.name; atTop: true; atLeft: false }
    Corner { screen: root.screen; screenName: root.screen.name; atTop: false; atLeft: true }
    Corner { screen: root.screen; screenName: root.screen.name; atTop: false; atLeft: false }
}
