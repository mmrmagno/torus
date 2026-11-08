//@ pragma IconTheme Tela-circle-dracula
//@ pragma Env QT_QPA_PLATFORMTHEME=qt6ct
import Quickshell
import qs.bar
import qs.services
import qs.notifications
import qs.osd
import qs.session
import qs.background
import qs.dashboard
import qs.overview
import qs.switcher
import qs.cheatsheet

ShellRoot {
    Variants {
        model: Quickshell.screens
        Scope {
            id: scope
            required property var modelData
            Background { screen: scope.modelData }
            DonutLayer { screen: scope.modelData }
        }
    }

    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
        }
    }

    Popups {}
    Center {}
    Osd {}
    Logout {}
    Dashboard {}
    Overview {}
    AltTab {}
    CheatSheet {}
    Ipc {}
}
