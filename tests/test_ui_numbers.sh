#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$REPO/home/.config/quickshell/torus"
bad=$(python3 - <<'P'
import os, re
num = re.compile(r'toFixed|Math\.round|Music\.fmt|cutter\.fmt|padStart|Timers\.text|formatTime|formatDateTime|\.length \+|\.count \+|Weather\.temp|rate\(|tile\.ago|[Pp]ercent')
for d, _, files in os.walk("."):
    for f in sorted(files):
        if not f.endswith(".qml"):
            continue
        L = open(os.path.join(d, f)).read().split("\n")
        for i, l in enumerate(L):
            m = re.match(r"^(\s*)(?:\w+:\s*)?Text \{", l)
            if not m:
                continue
            ind = len(m.group(1))
            j = i
            if l.count("{") != l.count("}"):
                j = i + 1
                while j < len(L) and not re.match(r"^\s{%d}\}" % ind, L[j]):
                    j += 1
            own = [x for k, x in enumerate(L[i:j + 1]) if k == 0 or len(x) - len(x.lstrip()) == ind + 4]
            b = "\n".join(own)
            if num.search(" ".join(x for x in own if re.search(r"\btext:", x))) and "Theme.fontUi" in b and "tnum" not in b:
                print(f"{os.path.join(d, f)[2:]}:{i + 1}")
P
)
[[ -z $bad ]] || fail "numbers that change need tnum or the mono face: $bad"
echo "ui numbers: ok"
