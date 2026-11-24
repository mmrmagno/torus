#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$REPO/home/.config/quickshell/torus"
raw=$(grep -rnE 'font\.pixelSize: *[0-9]+|pointSize:' --include='*.qml' . || true)
[[ -z $raw ]] || fail "text sizes are Theme.fs*, glyphs Theme.icon*, so text scale reaches them:
$raw"
caps=$(grep -rln 'font.letterSpacing: 1.2' --include='*.qml' . | grep -vE 'SectionTitle|clip/ClipPanel' || true)
[[ -z $caps ]] || fail "section titles are SectionTitle: $caps"
ico=$(python3 - <<'P'
import glob, re
for f in sorted(glob.glob("**/*.qml", recursive=True)):
    s = open(f).read()
    for m in re.finditer(r"fontUi[;\s]+(?:font\.\w+: [^\n;]+[;\s]+)*?font\.pixelSize: Theme\.icon", s):
        print(f + ":" + str(s[:m.start()].count("\n") + 1))
P
)
[[ -z $ico ]] || fail "Theme.icon* is for glyphs, words use Theme.fs*: $ico"
fam=$(grep -rnE 'font\.family: *"' --include='*.qml' . || true)
[[ -z $fam ]] || fail "faces are Theme.fontUi and Theme.fontMono: $fam"
short=$(python3 - <<'P'
import glob, re
for f in sorted(glob.glob("**/*.qml", recursive=True)):
    s = open(f).read()
    pad = re.search(r"contentHeight: (\w+)\.implicitHeight \+ (\d+)", s)
    if not pad:
        continue
    room = re.search(r"height: Math\.min\((?:Math\.max\()?%s\.implicitHeight[^\n]*?\+ (\d+)(?: \+ hintBar|, root)" % pad[1], s)
    at = s.rindex("Flickable {", 0, pad.start())
    top = re.search(r"anchors\.margins: (\d+)", s[at:pad.start()])
    low = re.search(r"anchors\.bottomMargin: (\d+)", s[at:pad.start()])
    if room and top:
        need = int(top[1]) + int(low[1] if low else top[1]) + int(pad[2])
        if int(room[1]) < need:
            print(f"{f} is {need - int(room[1])} px short")
P
)
[[ -z $short ]] || fail "a panel is as tall as what is in it, or its last row sits under the fade: $short"
echo "ui sizes: ok"
