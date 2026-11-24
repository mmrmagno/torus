#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
command -v node > /dev/null || { echo "skip: node missing"; exit 0; }
out=$(cd "$REPO" && node - <<'J'
const fs = require("fs")
const src = fs.readFileSync("home/.config/quickshell/torus/Theme.qml", "utf8")
const fn = n => src.match(new RegExp("    function " + n + "\\([^]*?\\n    }"))[0]
for (const f of fs.readdirSync("theme").filter(f => f.endsWith(".json"))) {
    const p = JSON.parse(fs.readFileSync("theme/" + f, "utf8"))
    const got = new Function("p", "const col = n => p[n]\n" + fn("light") + fn("contrast") + fn("readable") +
        "\nreturn [['subtext', 4.5], ['overlay', 3.9]].map(([n, least]) => { const c = " +
        "({ subtext: " + src.match(/color subtext: (.*)/)[1] + ", overlay: " + src.match(/color overlay: (.*)/)[1] + " })[n]; return [n, contrast(c, p.mantle), least, c] })")(p)
    for (const [n, c, least] of got)
        if (c < least) console.log(`${f}: ${n} has contrast ${c.toFixed(2)}, needs ${least}`)
    if (got[0][3] === got[1][3]) console.log(`${f}: both greys are the same color`)
    const mix = got[0][1] < got[1][1]
    if (mix) console.log(`${f}: overlay is louder than subtext`)
}
J
) || fail "Theme.qml no longer picks its greys by contrast"
[[ -z $out ]] || fail "greys people can't read: $out"
echo "ui contrast: ok"
