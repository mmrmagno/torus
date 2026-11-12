#!/usr/bin/env python3
import json
import os
import subprocess
import sys

import numpy as np


def layers(path, before):
    seen = {}
    t_open = t_close = None
    for line in open(path):
        line = line.strip()
        if line.startswith("#open"):
            t_open = float(line.split()[1])
            continue
        if line.startswith("#close"):
            t_close = float(line.split()[1])
            continue
        if not line:
            continue
        t, _, js = line.partition(" ")
        try:
            data = json.loads(js)
        except ValueError:
            continue
        for mon, m in data.items():
            for lvl in m.get("levels", {}).values():
                for l in lvl:
                    ns = os.environ.get("MOTION_NS")
                    if ns:
                        if l["namespace"] != ns or mon != os.environ.get("MOTION_MON", mon):
                            continue
                    elif l["address"] in before or not l["namespace"].startswith("torus"):
                        continue
                    seen.setdefault(l["address"], {"ns": l["namespace"], "mon": mon, "geo": []})
                    g = (l["x"], l["y"], l["w"], l["h"])
                    geo = seen[l["address"]]["geo"]
                    if not geo or geo[-1] != g:
                        geo.append(g)
    return seen, t_open, t_close


def frames(video, crop):
    x, y, w, h = crop
    turn = {"1": "transpose=2,", "2": "hflip,vflip,", "3": "transpose=1,"}.get(os.environ.get("MOTION_TRANSFORM", "0"), "")
    cmd = ["ffmpeg", "-v", "error", "-i", video, "-vf", f"{turn}crop={w}:{h}:{x}:{y},format=gray", "-f", "rawvideo", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    n = len(raw) // (w * h)
    return np.frombuffer(raw[: n * w * h], dtype=np.uint8).reshape(n, h, w)


def bbox(mask):
    rows = np.where(mask.any(axis=1))[0]
    cols = np.where(mask.any(axis=0))[0]
    if len(rows) == 0:
        return None
    return (int(cols[0]), int(rows[0]), int(cols[-1]), int(rows[-1]))


def phase(changed, lo, hi):
    idx = [i for i in range(lo, hi) if changed[i]]
    if not idx:
        return None
    a, b = idx[0], idx[-1]
    dropped = sum(1 for i in range(a, b + 1) if not changed[i])
    return a, b, dropped


def steps(boxes, changed, lo, hi, rest=12, gap=12, floor=0):
    boxes = [b if b and (b[2] - b[0] + 1) * (b[3] - b[1] + 1) >= floor else None for b in boxes]
    moves = []
    still = 0
    rested = False
    for i in range(lo + 1, hi):
        if boxes[i] is None or boxes[i - 1] is None:
            still = 0
            continue
        still = 0 if changed[i] else still + 1
        if not rested:
            rested = still >= rest
            continue
        if changed[i]:
            moves.append((i, [boxes[i][j] - boxes[i - 1][j] for j in range(4)]))
    out = 0
    for k, (i, d) in enumerate(moves):
        for j in range(4):
            if abs(d[j]) <= 2:
                continue
            before = moves[k - 1] if k and i - moves[k - 1][0] <= gap else None
            after = moves[k + 1] if k + 1 < len(moves) and moves[k + 1][0] - i <= gap else None
            if (before is None or before[1][j] * d[j] <= 0) and (after is None or after[1][j] * d[j] <= 0):
                out += 1
                break
    return out


def main():
    video, layerlog, beforefile, outw, outh = sys.argv[1:6]
    before = set(open(beforefile).read().split())
    seen, _, _ = layers(layerlog, before)
    crop = os.environ.get("MOTION_CROP")
    if crop:
        x, y, w, h = map(int, crop.split(","))
        seen = {"window": {"ns": "window", "mon": os.environ.get("MOTION_MON", ""), "geo": [(x, y, w, h)]}}
    if not seen:
        print(json.dumps({"error": "no new torus layer appeared"}))
        return 2
    addr, info = max(seen.items(), key=lambda kv: max(g[2] * g[3] for g in kv[1]["geo"]))
    geo = info["geo"]
    sizes = [(g[2], g[3]) for g in geo]
    resizes = sum(1 for a, b in zip(sizes, sizes[1:]) if a != b)
    moves = sum(1 for a, b in zip(geo, geo[1:]) if (a[0], a[1]) != (b[0], b[1]))
    ox, oy = (0, 0) if crop else (int(v) for v in os.environ.get("MOTION_ORIGIN", "0,0").split(","))
    x0 = max(0, min(g[0] for g in geo) - ox)
    y0 = max(0, min(g[1] for g in geo) - oy)
    x1 = min(int(outw), max(g[0] + g[2] for g in geo) - ox)
    y1 = min(int(outh), max(g[1] + g[3] for g in geo) - oy)
    w, h = (x1 - x0) // 2 * 2, (y1 - y0) // 2 * 2
    f = frames(video, (x0, y0, w, h)).astype(np.int16)
    n = len(f)
    if n < 10:
        print(json.dumps({"error": f"only {n} frames recorded"}))
        return 2
    area = w * h
    noise = max(200, area // 2000)
    changed = [False] + [int((np.abs(f[i] - f[i - 1]) > 6).sum()) > noise for i in range(1, n)]
    ref = f[0]
    boxes = []
    for i in range(n):
        b = bbox(np.abs(f[i] - ref) > 24)
        boxes.append(b if b and (b[2] - b[0] + 1) * (b[3] - b[1] + 1) >= area // 100 else None)
    best, run, split = 0, 0, n // 2
    for i in range(n):
        run = 0 if changed[i] or boxes[i] is None else run + 1
        if run > best:
            best, split = run, i - run // 2
    op = phase(changed, 0, split)
    cl = phase(changed, split, n)
    settled = boxes[split]
    floor = (settled[2] - settled[0] + 1) * (settled[3] - settled[1] + 1) // 4 if settled else 0
    jumps = steps(boxes, changed, 0, split, floor=floor)
    over = 0
    if settled:
        for b in boxes[:split]:
            if b:
                over = max(over, settled[0] - b[0], settled[1] - b[1], b[2] - settled[2], b[3] - settled[3])
    res = {
        "layer": info["ns"],
        "monitor": info["mon"],
        "frames": n,
        "resizes": resizes,
        "moves": moves,
        "jumps": jumps,
        "open_ms": round((op[1] - op[0] + 1) * 1000 / 60) if op else 0,
        "open_dropped": op[2] if op else 0,
        "close_ms": round((cl[1] - cl[0] + 1) * 1000 / 60) if cl else 0,
        "close_dropped": cl[2] if cl else 0,
        "overshoot_px": int(over),
        "box": settled,
    }
    print(json.dumps(res))
    return 0


if __name__ == "__main__":
    sys.exit(main())
