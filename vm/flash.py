#!/usr/bin/env python3
import json
import os
import subprocess
import sys

import numpy as np


def frames(video, w, h, turn):
    vf = {"1": "transpose=2,", "2": "hflip,vflip,", "3": "transpose=1,"}.get(turn, "") + f"scale={w // 4}:{h // 4},format=gray"
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", video, "-vf", vf, "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
    fw, fh = w // 4, h // 4
    n = len(raw) // (fw * fh)
    return np.frombuffer(raw[: n * fw * fh], dtype=np.uint8).reshape(n, fh, fw).astype(np.int16)


def main():
    video, w, h, bar, turn = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
    f = frames(video, w, h, turn)
    n = len(f)
    if n < 10:
        print(json.dumps({"error": f"only {n} frames"}))
        return 2
    strip = max(1, bar // 4)
    ref_bar = np.median(f[: min(10, n), :strip], axis=0)
    ref_wall = np.median(f[: min(10, n), strip:], axis=0)
    ref_mean = float(np.concatenate([ref_bar.ravel(), ref_wall.ravel()]).mean())
    dark = [float(f[i].mean()) < 6 for i in range(n)]
    skip = set()
    if os.environ.get("FLASH_OFF") and any(dark):
        i = dark.index(True)
        while i < n and dark[i]:
            skip.add(i)
            i += 1
    gone_bar = gone_wall = black = 0
    worst_bar = worst_wall = 0.0
    for i in range(n):
        if i in skip:
            continue
        k = float(f[i].mean()) / max(1.0, ref_mean)
        db = float((np.abs(f[i, :strip] - ref_bar * k) > 20).mean() * 100)
        dw = float((np.abs(f[i, strip:] - ref_wall * k) > 20).mean() * 100)
        worst_bar, worst_wall = max(worst_bar, db), max(worst_wall, dw)
        gone_bar += db > 12
        gone_wall += dw > 25
        black += dark[i]
    print(json.dumps({"frames": n, "off": len(skip), "bar_gone": gone_bar, "wall_gone": gone_wall, "black": black, "worst_bar": round(worst_bar, 1), "worst_wall": round(worst_wall, 1)}))
    return 0


sys.exit(main())
