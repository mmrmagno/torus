#!/usr/bin/env python3
import hashlib
import http.server
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse

USER, PASSWORD = "marcos", "app-pass-123"
LOG = sys.argv[2] if len(sys.argv) > 2 else os.devnull
SECONDS = int(os.environ.get("FAKE_SECONDS", "20"))

ARTISTS = [{"id": "ar1", "name": "Björk Fake", "albumCount": 2, "coverArt": "ar-ar1"},
           {"id": "ar2", "name": "Tone Band", "albumCount": 1, "coverArt": "ar-ar2"}]
ALBUMS = [{"id": "al1", "name": "Debut Tones", "artist": "Björk Fake", "artistId": "ar1", "year": 1993, "songCount": 2, "coverArt": "al-al1", "duration": 2 * SECONDS},
          {"id": "al2", "name": "Post Sines", "artist": "Björk Fake", "artistId": "ar1", "year": 1995, "songCount": 2, "coverArt": "al-al2", "duration": 2 * SECONDS, "starred": "2026-01-01T00:00:00Z"},
          {"id": "al3", "name": "Square Waves", "artist": "Tone Band", "artistId": "ar2", "year": 2001, "songCount": 2, "coverArt": "al-al3", "duration": 2 * SECONDS}]
EXTRA = int(os.environ.get("FAKE_ALBUMS", "0"))
DELAY = float(os.environ.get("FAKE_DELAY", "0"))
COVER_DELAY = float(os.environ.get("FAKE_COVER_DELAY", "0"))
for n in range(EXTRA):
    ar = "xr" + str(n // 3)
    if n % 3 == 0:
        ARTISTS.append({"id": ar, "name": "Extra Artist " + str(n // 3), "albumCount": 3, "coverArt": "ar-" + ar})
    ALBUMS.append({"id": "xl" + str(n), "name": "Extra Album " + str(n), "artist": "Extra Artist " + str(n // 3), "artistId": ar, "year": 1990 + n % 30, "songCount": 2, "coverArt": "al-xl" + str(n), "duration": 2 * SECONDS})
SONGS = []
for a in ALBUMS:
    for n in (1, 2):
        SONGS.append({"id": a["id"] + "-s" + str(n), "title": a["name"].split()[0] + " Song " + str(n), "album": a["name"], "albumId": a["id"],
                      "artist": a["artist"], "artistId": a["artistId"], "track": n, "year": a["year"], "duration": SECONDS,
                      "coverArt": a["coverArt"], "suffix": "flac"})
STARRED = set()
PLAYLIST = {"id": "pl1", "name": "Fake Mix", "songCount": 3, "duration": 3 * SECONDS, "coverArt": "pl-pl1"}

tmp = tempfile.mkdtemp(prefix="fake-subsonic-")
FLAC = os.path.join(tmp, "tone.flac")
JPG = os.path.join(tmp, "cover.jpg")
subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-f", "lavfi", "-i", "sine=frequency=330:duration=" + str(SECONDS), "-metadata", "title=Stream Tone", FLAC], check=True)
subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-f", "lavfi", "-i", "color=c=teal:s=120x120:d=1", "-frames:v", "1", JPG], check=True)
lock = threading.Lock()


def log(line):
    with lock, open(LOG, "a") as f:
        f.write(line + "\n")


def song(s):
    s = dict(s)
    if s["id"] in STARRED:
        s["starred"] = "2026-01-01T00:00:00Z"
    return s


class H(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def setup(self):
        super().setup()
        self.asked = 0
        log("connect")

    def log_message(self, *a):
        pass

    def reply(self, body, ok=True, error=None):
        r = {"subsonic-response": {"status": "ok" if ok else "failed", "version": "1.16.1", "openSubsonic": True, **body}}
        if error:
            r["subsonic-response"]["error"] = error
        data = json.dumps(r).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def file(self, path, ctype):
        data = open(path, "rb").read()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        self.asked += 1
        if self.asked > 1 and os.path.exists(LOG + ".deaf"):
            time.sleep(8)
        u = urllib.parse.urlsplit(self.path)
        q = {k: v[0] for k, v in urllib.parse.parse_qs(u.query).items()}
        ep = u.path.rsplit("/", 1)[-1]
        if not u.path.startswith("/StreamFin/rest/"):
            self.send_error(404)
            return
        if q.get("u") != USER or q.get("t") != hashlib.md5((PASSWORD + q.get("s", "")).encode()).hexdigest() or len(q.get("s", "")) < 6:
            log("auth-fail " + ep)
            self.reply({}, False, {"code": 40, "message": "Wrong username or password"})
            return
        if "p" in q:
            log("plain-password " + ep)
        log(ep + " " + " ".join(k + "=" + q[k] for k in ("id", "type", "query", "submission", "format", "artist", "size") if k in q))
        if os.path.exists(LOG + ".slow"):
            time.sleep(0.5)
        time.sleep(COVER_DELAY if ep == "getCoverArt" else DELAY)
        if ep == "ping":
            self.reply({})
        elif ep == "getOpenSubsonicExtensions":
            self.reply({"openSubsonicExtensions": [{"name": "songLyrics", "versions": [1]}]})
        elif ep == "search3":
            w = q.get("query", "").lower()
            self.reply({"searchResult3": {"artist": [a for a in ARTISTS if w in a["name"].lower()],
                                          "album": [a for a in ALBUMS if w in (a["name"] + a["artist"]).lower()],
                                          "song": [song(s) for s in SONGS if w in (s["title"] + s["artist"] + s["album"]).lower()]}})
        elif ep == "getAlbumList2":
            t = q.get("type")
            al = [a for a in ALBUMS if a.get("starred")] if t == "starred" else ALBUMS
            if t == "newest" and os.path.exists(LOG + ".fresh"):
                al = [{"id": "alnew", "name": "Fresh Pressing", "artist": "Tone Band", "artistId": "ar2", "year": 2026, "songCount": 0, "coverArt": "al-alnew", "duration": 0}] + al
            self.reply({"albumList2": {"album": al[:int(q.get("size", "10"))]}})
        elif ep == "getArtists":
            self.reply({"artists": {"index": [{"name": "B", "artist": [ARTISTS[0]]}, {"name": "T", "artist": [ARTISTS[1]]}]}})
        elif ep == "getArtist":
            a = next(x for x in ARTISTS if x["id"] == q.get("id"))
            self.reply({"artist": {**a, "album": [x for x in ALBUMS if x["artistId"] == a["id"]]}})
        elif ep == "getAlbum":
            a = next((x for x in ALBUMS if x["id"] == q.get("id")), None)
            if not a:
                self.reply({}, False, {"code": 70, "message": "not found"})
                return
            self.reply({"album": {**a, "song": [song(s) for s in SONGS if s["albumId"] == a["id"]]}})
        elif ep == "getSong":
            self.reply({"song": song(next(s for s in SONGS if s["id"] == q.get("id")))})
        elif ep == "getTopSongs":
            self.reply({"topSongs": {"song": [song(s) for s in SONGS if s["artist"] == q.get("artist")][:3]}})
        elif ep == "getRandomSongs":
            self.reply({"randomSongs": {"song": [song(s) for s in SONGS]}})
        elif ep == "getStarred2":
            self.reply({"starred2": {"album": [a for a in ALBUMS if a.get("starred")], "song": [song(s) for s in SONGS if s["id"] in STARRED]}})
        elif ep == "getPlaylists":
            self.reply({"playlists": {"playlist": [PLAYLIST]}})
        elif ep == "getPlaylist":
            self.reply({"playlist": {**PLAYLIST, "entry": [song(s) for s in SONGS[:3]]}})
        elif ep in ("star", "unstar"):
            (STARRED.add if ep == "star" else STARRED.discard)(q.get("id"))
            self.reply({})
        elif ep == "scrobble":
            self.reply({})
        elif ep == "getCoverArt":
            self.file(JPG, "image/jpeg")
        elif ep == "stream":
            self.file(FLAC, "audio/flac")
        else:
            self.reply({}, False, {"code": 0, "message": "unknown " + ep})


srv = http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 0), H)
print(srv.server_address[1], flush=True)
srv.serve_forever()
