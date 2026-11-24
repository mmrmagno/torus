#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$REPO/home/.config/quickshell/torus"
bad=$(python3 - <<'P'
import os, re
# the lock lets go after a fixed time, its fade has to fit in it
allow = {"lock/LockSurface.qml": ("duration: 180; easing.type: Easing.InCubic", "duration: 200; easing.type: Easing.InCubic", "lock.fading ?")}
for d, _, files in os.walk("."):
    for f in sorted(files):
        if not f.endswith(".qml"):
            continue
        p = os.path.join(d, f)[2:]
        L = open(p).read().split("\n")
        loops = set()
        for i, l in enumerate(L):
            if "Animation.Infinite" not in l:
                continue
            k = i
            if "{" not in l:
                ind = len(l) - len(l.lstrip())
                while not (L[k].rstrip().endswith("{") and len(L[k]) - len(L[k].lstrip()) < ind):
                    k -= 1
                e = k
                while e < len(L) and not (L[e].strip() == "}" and len(L[e]) - len(L[e].lstrip()) == len(L[k]) - len(L[k].lstrip())):
                    e += 1
            else:
                e = i
            loops.update(range(k, e + 1))
            run = [x for x in L[k:e + 1] if "running:" in x]
            if not run or not ("Theme.motion > 0" in run[0] or "root.breathe" in run[0]):
                print(f"{p}:{k + 1} loops with motion off")
        for i, l in enumerate(L):
            c = re.search(r"\b(?:Animation|PauseAnimation) \{.*\bduration: *([^;}]+)", l)
            if c and i not in loops and not re.search(r"Theme\.(dur|motion)|^0\b|^[0-9]+\b|lock\.fading", c[1]):
                print(f"{p}:{i + 1} has a computed duration the motion settings can't reach")
        for i, l in enumerate(L):
            m = re.search(r"\bduration: *(lock\.fading \?|[0-9]+\b(?! *\*))", l)
            if m and i not in loops and not re.search(r"property \w+ duration", l) and not re.search(r"duration: 0\b", l) and not any(a in l for a in allow.get(p, ())):
                print(f"{p}:{i + 1} has a duration the motion settings can't reach")
P
)
[[ -z $bad ]] || fail "motion follows Theme.dur* or Theme.motion:
$bad"
echo "ui motion: ok"
