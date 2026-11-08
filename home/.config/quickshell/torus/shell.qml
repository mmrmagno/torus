//@ pragma IconTheme Tela-circle-dracula
//@ pragma Env QT_QPA_PLATFORMTHEME=qt6ct
import Quickshell
import qs.bar
import qs.services
import qs.notifications
import qs.island
import qs.lock
import qs.widgets
import qs.clip
import qs.ai
import qs.polkit
import qs.corners
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
            Widgets { screen: scope.modelData }
            Corners { screen: scope.modelData }
        }
    }

    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        DynamicIsland {
            required property var modelData
            screen: modelData
        }
    }

    Popups {}
    Center {}
    Logout {}
    Dashboard {}
    Overview {}
    AltTab {}
    CheatSheet {}
    ClipPanel {}
    AiPanel {}
    Polkit {}
    Lock {}
    Ipc {}
}
