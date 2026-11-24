#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
run=$(command -v qmltestrunner6 || ls /usr/lib/qt6/bin/qmltestrunner 2> /dev/null || true)
[[ -n $run ]] || { echo "skip: qmltestrunner missing"; exit 0; }
F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/qs/components" "$F/t"
S=$REPO/home/.config/quickshell/torus
cp "$S/components/Tap.qml" "$S/components/Press.qml" "$F/qs/components/"
printf 'module qs\nsingleton Theme 1.0 Theme.qml\nsingleton Store 1.0 Store.qml\n' > "$F/qs/qmldir"
printf 'module qs.components\nTap 1.0 Tap.qml\nPress 1.0 Press.qml\n' > "$F/qs/components/qmldir"
printf 'pragma Singleton\nimport QtQuick\nQtObject { property int durFast: 140 }\n' > "$F/qs/Theme.qml"
{ printf 'pragma Singleton\nimport QtQuick\nQtObject {\n'; sed -n '/^    function over(/,/^    }/p' "$S/Store.qml"; printf '}\n'; } > "$F/qs/Store.qml"
cat > "$F/t/tst_press.qml" <<'Q'
import QtQuick
import QtTest
import qs
import qs.components

Item {
    id: root
    width: 300
    height: 200
    property int cog: 0
    property int launch: 0

    Rectangle {
        id: card
        width: 200
        height: 120
        Rectangle {
            id: button
            x: 150
            y: 20
            width: 28
            height: 28
            Tap { onTapped: root.cog++ }
        }
        Tap {
            onTapped: (point, b) => {
                if (Store.over(button, card, point.position))
                    return
                root.launch++
            }
        }
    }

    TestCase {
        name: "Press"
        when: windowShown
        function tap(x, y) {
            mousePress(root, x, y)
            wait(220)
            mouseRelease(root, x, y)
            wait(220)
        }
        function test_edges_data() {
            const out = []
            for (const d of [0, 1, 2, 13, 26, 27])
                out.push({ tag: "px " + d, x: 150 + d, y: 34 }, { tag: "py " + d, x: 164, y: 20 + d })
            return out
        }
        function test_edges(row) {
            root.cog = root.launch = 0
            tap(row.x, row.y)
            compare(root.launch, 0, "the row under the button answered")
            compare(root.cog, 1, "the button did not answer")
        }
        function test_card() {
            root.cog = root.launch = 0
            tap(30, 60)
            compare(root.launch, 1)
            compare(card.scale, 1)
            mousePress(root, 30, 60)
            wait(220)
            verify(card.scale < 1 && card.scale >= 0.9)
            mouseRelease(root, 30, 60)
            tryCompare(card, "scale", 1)
        }
    }
}
Q
out=$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$run" -import "$F" -input "$F/t" 2>&1) || fail "a press never moves the click: $(grep -E 'FAIL|rror' <<< "$out" | head -6)"
grep -q ', 0 failed' <<< "$out" || fail "press tests did not run: $(tail -3 <<< "$out")"
echo "ui press: ok"
