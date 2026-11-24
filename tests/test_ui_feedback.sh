#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$REPO/home/.config/quickshell/torus"
bad=$(python3 - <<'P'
import os, re
# a blocker, a whole surface or a drag: what is under the pointer already shows what happens
allow = {
    ("palette/FileLook.qml", "acceptedButtons: Qt.AllButtons"), ("games/GameSettings.qml", "acceptedButtons: Qt.AllButtons"),
    ("components/QrCode.qml", "acceptedButtons: Qt.AllButtons"), ("components/QuickLook.qml", "acceptedButtons: Qt.AllButtons"),
    ("components/Picker.qml", "acceptedButtons: Qt.AllButtons"), ("music/MusicSettings.qml", "z: -1"),
    ("pin/PinWindow.qml", "property point from"), ("cheatsheet/CheatSheet.qml", 'setOpen("cheatsheet", false)'),
    ("games/ClipCutter.qml", "if (cutter.duration > 0) cutter.togglePlay()"), ("ruler/Ruler.qml", "Qt.CrossCursor"), ("draw/Draw.qml", "Qt.CrossCursor"),
    ("notifications/NotifCard.qml", "acceptedButtons: Qt.NoButton"), ("components/ValueSlider.qml", "root.setFrom"),
    ("dashboard/Dashboard.qml", "parent.a.volume"), ("dashboard/Dashboard.qml", "function pick(x)"),
    ("music/NowPlaying.qml", '"seek"'), ("notifications/MediaCard.qml", "canSeek"), ("components/Picker.qml", "onPositionChanged: root.index"),
    ("notifications/NotifCard.qml", "card.activate()"), ("games/ClipCutter.qml", "acceptedButtons: Qt.AllButtons"), ("games/ClipCutter.qml", "property real from"),
    ("components/SettingsSheet.qml", "acceptedButtons: Qt.AllButtons"), ("music/MusicPanel.qml", "root.menuRow = null"), ("clip/ClipPanel.qml", "id: grip"),
    ("overview/Overview.qml", 'setOpen("overview", false) }'), ("session/Logout.qml", 'setOpen("logout", false)'), ("lock/LockSurface.qml", "root.forceActiveFocus()"),
    ("island/DynamicIsland.qml", "id: pillArea"), ("components/GameSettingRow.qml", "item.owner.index = item.rowIndex"),
}
for d, _, files in os.walk("."):
    for f in sorted(files):
        if not f.endswith(".qml") or f == "Tap.qml":
            continue
        p = os.path.join(d, f)[2:]
        L = open(p).read().split("\n")
        def end(i, ind):
            if L[i].count("{") == L[i].count("}"):
                return i
            j = i + 1
            while j < len(L) and not re.match(r"^\s{%d}\}" % ind, L[j]):
                j += 1
            return j
        for i, l in enumerate(L):
            m = re.match(r"^(\s*)(?:[\w.]+:\s*)?(TapHandler|Tap|MouseArea) \{", l)
            if not m:
                continue
            ind = len(m.group(1))
            own = "\n".join(L[i:end(i, ind) + 1])
            if any(p == a and b in own for a, b in allow):
                continue
            k = i - 1
            while k >= 0 and not (re.match(r"^\s*(?:[\w.]+:\s*)?(?:component \w+: )?[A-Z]\w* \{$", L[k]) and len(L[k]) - len(L[k].lstrip()) < ind):
                k -= 1
            e = end(k, len(L[k]) - len(L[k].lstrip()))
            hand = over = False
            for n in range(k + 1, e):
                if len(L[n]) - len(L[n].lstrip()) == ind and re.match(r"\s*(?:[\w.]+:\s*)?(HoverHandler|MouseArea) \{", L[n]):
                    h = "\n".join(L[n:end(n, ind) + 1])
                    name = re.search(r"\bid: (\w+)", h)
                    hand = hand or "cursorShape" in h
                    over = over or "onHoveredChanged" in h or "onPositionChanged" in h or bool(name and re.search(r"\b%s\.(hovered|containsMouse)\b" % name[1], "\n".join(L)))
            name = re.search(r"\bid: (\w+)", own)
            down = m.group(2) == "Tap" or bool(name and re.search(r"\b%s\.(pressed|containsPress)\b" % name[1], "\n".join(L)))
            miss = [n for n, ok in (("a cursor", hand), ("a hover state", over), ("a pressed state", down)) if not ok]
            if miss:
                print(f"{p}:{i + 1} has no {' and no '.join(miss)}")
P
)
[[ -z $bad ]] || fail "everything you can click shows a hand, reacts to hover and goes down on press (Tap, Press):
$bad"
grep -q 'margin: reach + (pressed ? 6 : 0)' components/Tap.qml || fail "a pressed item shrinks, its edge must still count"
grep -rn 'contains([a-zA-Z]*.mapFromItem' --include='*.qml' . && fail "a row asks Store.over() whether a button was meant, the button shrinks while pressed"
grep -q 'onSizeChanged: if (target) target.scale = size' components/Press.qml || fail "Press must scale its target"
own=$(grep -rnE '^\s*color: "#|color: "(white|black|red|gray|grey)"' --include='*.qml' . | grep -v components/QrCode.qml || true)
[[ -z $own ]] || fail "colors come from Theme: $own"
gb=$(grep -rniE '"[^"]*\b(centre|colour|favourite|grey|behaviour|organise|cancelled)\b[^"]*"' --include='*.qml' . | grep -viE 'import|source:|\.get\(|=== "|case "' || true)
[[ -z $gb ]] || fail "American spelling in what people read: $gb"
echo "ui feedback: ok"
