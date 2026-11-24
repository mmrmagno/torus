#!/usr/bin/env python3
import glob
import json
import os
import signal
import socket
import subprocess
import sys
import time

RUN = os.environ["XDG_RUNTIME_DIR"]
HYPR = RUN + "/hypr/" + os.environ["HYPRLAND_INSTANCE_SIGNATURE"] + "/.socket.sock"
HOME = os.path.expanduser("~")
ROWS = []


def hypr(cmd):
    s = socket.socket(socket.AF_UNIX)
    s.connect(HYPR)
    s.sendall(cmd.encode())
    out = b""
    while True:
        b = s.recv(65536)
        if not b:
            break
        out += b
    s.close()
    return out.decode("utf-8", "replace")


def ipc(*args):
    r = subprocess.run(["qs", "-c", "torus", "ipc", "call", "torus", *map(str, args)], capture_output=True, text=True, timeout=10)
    lines = [x for x in r.stdout.splitlines() if x.strip()]
    return lines[-1] if lines else ""


def panels():
    try:
        d = json.loads(hypr("j/layers"))
    except ValueError:
        return 0
    return sum(1 for m in d.values() for lv in m["levels"].values() for x in lv if x["namespace"] in ("torus-panel", "torus-hub", "torus-palette"))


def wait(fn, limit=15.0, step=0.004):
    t0 = time.monotonic()
    while time.monotonic() - t0 < limit:
        v = fn()
        if v:
            return v
        time.sleep(step)
    return None


def key(*args):
    subprocess.Popen(["wtype", *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def ms(t0):
    return round((time.monotonic() - t0) * 1000)


def note(name, mapped, rows, ready):
    ROWS.append([name, mapped, rows, ready])
    show = lambda v: "-" if v is None else str(v)
    print("| " + " | ".join([name, show(mapped), show(rows), show(ready)]) + " |", flush=True)


def close_all():
    ipc("closeAll")
    wait(lambda: panels() == 0, 3)
    time.sleep(0.5)


def music(want):
    p = ipc("musicSpot").split("|")
    if len(p) < 5 or (want and p[0] != want):
        return None
    return (p[3], int(p[4] or 0))


def music_until(want, t0):
    first = None

    def done():
        nonlocal first
        m = music(want)
        if not m:
            return False
        if m[0] in ("ready", "part") and m[1] > 0 and first is None:
            first = ms(t0)
        return m[0] == "ready" and m[1] > 0
    ok = wait(done, step=0)
    return first, (ms(t0) if ok else None)


def music_open(name, want="home"):
    t0 = time.monotonic()
    ipc("musicToggle")
    mapped = ms(t0) if wait(panels, 5) else None
    rows, ready = music_until(want, t0)
    note(name, mapped, rows, ready)


def music_tab(name, want):
    t0 = time.monotonic()
    key("-k", "Tab")
    note(name, None, *music_until(want, t0))


def go_home():
    ipc("musicToggle")
    wait(panels, 3)
    for _ in range(8):
        time.sleep(0.4)
        spot = ipc("musicSpot").split("|")
        if spot[0] == "home":
            break
        key("-k", "Escape" if spot[0] in ("search", "detail") else "Tab")
    close_all()


def sweep(tag):
    if tag == "again":
        go_home()
    music_open("music: open Home " + tag)
    music_tab("music: Albums " + tag, "albums")
    music_tab("music: Artists " + tag, "artists")
    music_tab("music: Playlists " + tag, "playlists")
    close_all()
    go_home()
    ipc("musicToggle")
    wait(lambda: (music("home") or ("",))[0] == "ready", 15)
    time.sleep(0.3)
    t0 = time.monotonic()
    key("square")
    note("music: search " + tag, None, *music_until("search", t0))
    key("-k", "Escape")
    time.sleep(0.5)
    key("-k", "Down")
    time.sleep(0.4)
    t0 = time.monotonic()
    key("-M", "shift", "-k", "space", "-m", "shift")
    note("music: open an album " + tag, None, *music_until("detail", t0))
    key("-k", "Escape")
    wait(lambda: music("home"), 2)
    close_all()
    q = "m square" if tag == "first visit" else "m song"
    t0 = time.monotonic()
    ipc("paletteQuery", q)
    got = wait(lambda: "music:" in ipc("paletteRows", 3), 15, 0)
    note("palette: " + q + " " + tag, None, ms(t0) if got else None, None)
    close_all()


def music_speed():
    base = HOME + "/.cache/torus-speed"
    cfg, cache = HOME + "/.config/torus/music.json", HOME + "/.cache/torus/music"
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sys.path.insert(0, repo)
    subprocess.run(["pkill", "-f", "[f]ake-subsonic.py 18766"])
    keep = {p: open(p).read() if os.path.exists(p) else None for p in (cfg, cache + "/local.json")}
    files = {}
    for a in range(250):
        d = base + "/Music/Artist " + str(a // 2) + "/Album " + str(a)
        os.makedirs(d, exist_ok=True)
        for n in range(10):
            p = d + "/" + str(n) + ".flac"
            if not os.path.exists(p):
                open(p, "w").close()
            files[p] = {"title": "Local Song " + str(a) + " " + str(n), "artist": "Artist " + str(a // 2), "albumartist": "Artist " + str(a // 2),
                        "album": "Album " + str(a), "year": 2000, "track": n, "disc": 1, "seconds": 200, "m": int(os.stat(p).st_mtime)}
    env = dict(os.environ, FAKE_ALBUMS="300", FAKE_DELAY="0.25", FAKE_COVER_DELAY="0.08", FAKE_SECONDS="5")
    srv = subprocess.Popen([sys.executable, repo + "/tests/fake-subsonic.py", "18766", "/tmp/speed-subsonic.log"], env=env, stdout=subprocess.PIPE, text=True)
    srv.stdout.readline()
    try:
        subprocess.run(["torus-music", "login", "Fake", "http://127.0.0.1:18766/StreamFin", "marcos"], input="app-pass-123\n", text=True, check=True, stdout=subprocess.DEVNULL)
        c = json.load(open(cfg))
        c["folder"] = base + "/Music"
        json.dump(c, open(cfg, "w"))
        json.dump({"root": os.path.realpath(base + "/Music"), "at": int(time.time()), "files": files, "covers": {}}, open(cache + "/local.json", "w"))
        for p in glob.glob(cache + "/covers/*") + glob.glob(cache + "/browse*"):
            os.remove(p)
        subprocess.run(["systemctl", "--user", "stop", "torus-music"])
        subprocess.run(["systemctl", "--user", "restart", "torus-shell"])
        time.sleep(8)
        ipc("stayAwake", "true")
        sweep("first visit")
        time.sleep(1)
        sweep("again")
    finally:
        close_all()
        srv.kill()
        subprocess.run(["torus-music", "logout", "Fake"], stdout=subprocess.DEVNULL)
        for p, v in keep.items():
            if v is None:
                if os.path.exists(p):
                    os.remove(p)
            else:
                open(p, "w").write(v)
        for p in glob.glob(cache + "/covers/*") + glob.glob(cache + "/browse*"):
            os.remove(p)
        subprocess.run(["systemctl", "--user", "restart", "torus-music"])


def picture(size, n, path):
    subprocess.run(["magick", "-size", "x".join(str(int(v) // 4) for v in size.split("x")), "plasma:navy-orange", "-scale", size + "!", "-depth", "8", "-alpha", "off",
                    "-fill", "white", "-draw", "point " + str(n) + ",5", "-quality", "30", path], check=True)


def clip_speed():
    subprocess.run(["cliphist", "wipe"])
    src = "/tmp/speed-shot.png"
    for n, (size, gap, tag) in enumerate((("1920x1080", 0, "right after"), ("1920x1080", 3, "3 s after"), ("3440x1440", 0, "right after"), ("3440x1440", 3, "3 s after"))):
        picture(size, n, src)
        mb = str(round(os.path.getsize(src) / 1e6, 1)) + " MB"
        close_all()
        subprocess.run("wl-copy --type image/png < " + src, shell=True)
        time.sleep(gap)
        clip_open("clipboard: " + size + " " + mb + ", opened " + tag, size, 1 + n)
    for n in range(8):
        picture("3440x1440", 20 + n, src)
        subprocess.run("wl-copy --type image/png < " + src, shell=True)
        time.sleep(1.5)
    clip_open("clipboard: 8 new 3440x1440 pictures", "3440x1440", 6)
    subprocess.run(["systemctl", "--user", "restart", "torus-shell"])
    time.sleep(9)
    ipc("stayAwake", "true")
    clip_open("clipboard: the same after a shell restart", "3440x1440", 6)
    clip_open("clipboard: the same, opened again", "3440x1440", 6)
    os.remove(src)


def clip_open(name, size, rows):
    t0 = time.monotonic()
    ipc("clipToggle")
    mapped = ms(t0) if wait(panels, 5) else None
    row = big = None
    while ms(t0) < 6000 and not (row and big):
        p = ipc("clipPicture").split("|")
        if len(p) == 3 and p[0] == "image " + size:
            have, want = (int(x) for x in p[1].split("/"))
            row = row or (ms(t0) if want >= min(rows, 6) and have >= want else None)
            big = big or (ms(t0) if p[2] else None)
    note(name, mapped, row, big)
    close_all()


PANELS = ["dashboard", "palette", "clip", "center", "music", "games", "overview", "network", "updates", "theme", "session", "cheatSheet", "processes", "capture", "ai", "homelab"]


def panel_speed():
    subprocess.run(["systemctl", "--user", "restart", "torus-shell"])
    time.sleep(10)
    ipc("stayAwake", "true")
    for p in PANELS:
        took = []
        for _ in range(4):
            close_all()
            t0 = time.monotonic()
            ipc(p + "Toggle")
            took.append(ms(t0) if wait(panels, 3) else None)
        rest = sorted(x for x in took[1:] if x is not None)
        note("open " + p, took[0], None, rest[len(rest) // 2] if rest else None)
    close_all()


def palette_speed():
    for q in ("kitty", "lock", "= 2+2"):
        close_all()
        t0 = time.monotonic()
        ipc("paletteQuery", q)
        got = wait(lambda: ":" in ipc("paletteRows", 1), 4, 0)
        note("palette: " + q, None, ms(t0) if got else None, None)
    close_all()


def bar_measure():
    burn = [subprocess.Popen(["sh", "-c", "sleep 2; timeout 5 sh -c 'while :; do :; done'"]) for _ in range(8)]
    for m in json.loads(hypr("j/monitors")):
        seen = {}
        t0 = time.monotonic()
        while time.monotonic() - t0 < 10:
            b = json.loads(ipc("barBoxes", m["name"]) or "{}")
            for k, v in (b.get("modules") or {}).items():
                seen.setdefault(k, set()).add(v["w"])
        moved = {k: sorted(v) for k, v in seen.items() if len(v) > 1}
        small = {k: [h for h in v["hits"] if h[0] < 28 or h[1] < b["h"]] for k, v in b["modules"].items()}
        small = {k: v for k, v in small.items() if v}
        print("bar " + m["name"] + ": " + json.dumps({"modules": len(b["modules"]), "width jitter": moved, "hit areas under 28 x " + str(b["h"]): small}), flush=True)
    for p in burn:
        p.wait()


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *a: sys.exit(1))
    signal.signal(signal.SIGHUP, lambda *a: sys.exit(1))
    t0 = time.monotonic()
    ipc("isOpen", "music")
    print("probe cost: " + str(ms(t0)) + " ms per shell call", flush=True)
    print("| moment | mapped ms | first rows ms | ready ms |\n|---|---|---|---|", flush=True)
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "music"):
        music_speed()
    if what in ("all", "clip"):
        clip_speed()
    if what in ("all", "panels"):
        panel_speed()
    if what in ("all", "palette"):
        palette_speed()
    if what in ("all", "bar"):
        bar_measure()
