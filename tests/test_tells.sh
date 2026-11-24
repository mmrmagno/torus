#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$REPO/home"
hits=$(python3 - <<'P'
import os
allow = {".local/bin/torus-webapp": "clean_name", ".config/hypr/torus/rules.lua": "Dolphin"}
for d, _, files in os.walk("."):
    for f in files:
        p = os.path.join(d, f)[2:]
        try:
            lines = open(p, encoding="utf-8").read().split("\n")
        except (UnicodeDecodeError, OSError):
            continue
        for n, line in enumerate(lines, 1):
            if any(c in line for c in "·•∙⋅–—") and not (p in allow and allow[p] in line):
                if p.endswith("services/Notifs.qml") and "plain.split(code)" in line:
                    continue
                print(p + ":" + str(n) + ": " + line.strip()[:120])
P
)
[[ -z $hits ]] || fail "middle dots or long dashes in what people read:
$hits"
hits=$(grep -rnE "OutBack|overshoot" .config/quickshell/torus --include='*.qml' | grep -vE "/(island/DynamicIsland|background/Donut(View|Layer))\.qml" || true)
[[ -z $hits ]] || fail "overshoot outside the island and the donut:
$hits"
echo "tells: ok"
