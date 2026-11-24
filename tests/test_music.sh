#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

if [[ -z ${MUSIC_BUS:-} ]]; then
  exec env MUSIC_BUS=1 dbus-run-session -- bash "$0" "$@"
fi

F=$(mktemp -d)
cleanup() {
  [[ -n ${SRV:-} ]] && kill "$SRV" 2>/dev/null
  pkill -f "$F/bin/[t]orus-music daemon" 2>/dev/null || true
  pkill -f "input-ipc-server=$F/" 2>/dev/null || true
  rm -rf "$F"
}
trap cleanup EXIT
export HOME=$F/home XDG_CONFIG_HOME=$F/home/.config XDG_CACHE_HOME=$F/home/.cache XDG_STATE_HOME=$F/home/.local/state
export XDG_RUNTIME_DIR=$F/run STUB_LOG=$F/calls FAKE_SECONDS=10
mkdir -p "$HOME/Music" "$F/bin" "$F/keyring" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
cp "$REPO/home/.local/bin/torus-music" "$F/bin/torus-music"

cat > "$F/bin/mpv" <<'S'
#!/usr/bin/env bash
exec /usr/bin/mpv --ao=null "$@"
S
cat > "$F/bin/secret-tool" <<S
#!/usr/bin/env bash
echo "secret-tool \$1" >> "\$STUB_LOG"
k=$F/keyring/\${@: -1}
case \$1 in
  store) cat > "\$k" ;;
  lookup) [[ -f \$k ]] && cat "\$k" ;;
  clear) rm -f "\$k" ;;
esac
S
cat > "$F/bin/systemctl" <<S
#!/usr/bin/env bash
echo "systemctl \$*" >> "\$STUB_LOG"
if [[ \$* == *start*torus-music.service* ]]; then
  setsid "$F/bin/torus-music" daemon >> "$F/daemon.log" 2>&1 < /dev/null &
fi
exit 0
S
printf '#!/usr/bin/env bash\necho "qs $*" >> "$STUB_LOG"\n' > "$F/bin/qs"
chmod +x "$F/bin"/*
export PATH=$F/bin:$PATH
M=$F/bin/torus-music

tone() {
  ffmpeg -v quiet -y -f lavfi -i "sine=frequency=$1:duration=6" -metadata title="$2" -metadata artist="$3" -metadata album="$4" -metadata track="$5" "$6"
}
mkdir -p "$HOME/Music/Local Artist/Café Album" "$HOME/Music/Other/Embedded"
tone 220 "Morning Song" "Local Artist" "Café Album" 1 "$HOME/Music/Local Artist/Café Album/01.flac"
tone 240 "Evening Song" "Local Artist" "Café Album" 2 "$HOME/Music/Local Artist/Café Album/02.flac"
ffmpeg -v quiet -y -f lavfi -i "color=c=red:s=64x64:d=1" -frames:v 1 "$HOME/Music/Local Artist/Café Album/cover.jpg"
tone 260 "Hidden Track" "Other" "Embedded" 1 "$F/raw.flac"
ffmpeg -v quiet -y -f lavfi -i "color=c=blue:s=64x64:d=1" -frames:v 1 "$F/blue.jpg"
ffmpeg -v quiet -y -i "$F/raw.flac" -i "$F/blue.jpg" -map 0:a -map 1:v -c copy -disposition:v attached_pic "$HOME/Music/Other/Embedded/01.flac"
echo "not audio" > "$HOME/Music/notes.txt"

j() { python3 -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1]))" "$1"; }

out=$("$M" index 2>/dev/null)
assert_eq 3 "$(j 'd["tracks"]' <<< "$out")" "index finds three tracks"
alb=$("$M" albums local)
assert_eq 2 "$(j 'len(d["rows"])' <<< "$alb")" "two local albums"
assert_eq "cover.jpg" "$(j '[r["cover"].rsplit("/",1)[-1] for r in d["rows"] if r["title"]=="Café Album"][0]' <<< "$alb")" "folder cover used"
emb=$(j '[r["cover"] for r in d["rows"] if r["title"]=="Embedded"][0]' <<< "$alb")
[[ -s $emb ]] || fail "embedded cover extracted"
s=$("$M" search "cafe morning" local)
assert_eq "Morning Song" "$(j 'd["tracks"][0]["title"]' <<< "$s")" "accent-free local search"

PORT=$(mktemp)
python3 "$REPO/tests/fake-subsonic.py" 0 "$F/server.log" > "$PORT" &
SRV=$!
for _ in $(seq 50); do [[ -s $PORT ]] && break; sleep 0.1; done
URL="http://127.0.0.1:$(cat "$PORT")/StreamFin"

rc=0
printf 'wrong' | "$M" login Fake "$URL" marcos > "$F/bad" || rc=$?
assert_eq 1 "$rc" "wrong password refused"
assert_contains "$F/bad" "wrong user or password"
assert_absent "$F/keyring/Fake"
printf 'app-pass-123' | "$M" login Fake "$URL" marcos > /dev/null
assert_eq "app-pass-123" "$(cat "$F/keyring/Fake")" "password stored in the keyring"
grep -q 'app-pass' "$XDG_CONFIG_HOME/torus/music.json" && fail "password in the config"
assert_eq 600 "$(stat -c %a "$XDG_CONFIG_HOME/torus/music.json")" "config mode"
rc=0
printf 'x' | "$M" login Bad "ftp://host" marcos > "$F/bad" || rc=$?
assert_eq 1 "$rc" "non-http address refused"

home=$("$M" home)
titles=$(j '",".join(s["title"] for s in d["sections"])' <<< "$home")
assert_eq "Recently added,Starred,Most played,Random" "$titles" "home sections"
assert_eq "Post Sines" "$(j '[r["title"] for s in d["sections"] if s["title"]=="Starred" for r in s["rows"]][0]' <<< "$home")" "starred from the server"
cov=$(j '[r["cover"] for s in d["sections"] for r in s["rows"] if r["source"]=="Fake"][0]' <<< "$home")
[[ -s $cov ]] || fail "server cover cached"

s=$("$M" search "debut")
assert_eq "Fake" "$(j 'd["tracks"][0]["source"]' <<< "$s")" "server search"
rm -rf "$XDG_CACHE_HOME/torus/music/covers"
before=$(grep -c "^getCoverArt id=al-al1" "$F/server.log")
o=$("$M" open album Fake al1)
assert_eq 2 "$(j 'len(d["tracks"])' <<< "$o")" "open album"
assert_eq 1 "$(j 'len({t["cover"] for t in d["tracks"]} | {d["head"]["cover"]})' <<< "$o")" "one cover for the whole album"
[[ -s $(j 'd["head"]["cover"]' <<< "$o") ]] || fail "album cover cached"
assert_eq $((before + 1)) "$(grep -c "^getCoverArt id=al-al1" "$F/server.log")" "shared cover asked for once"
o=$("$M" open artist Fake ar1)
assert_eq 2 "$(j 'len(d["albums"])' <<< "$o")" "artist albums"
assert_eq 1995 "$(j 'd["albums"][0]["year"]' <<< "$o")" "newest album first"
o=$("$M" playlists)
assert_eq "Fake Mix" "$(j 'd["rows"][0]["title"]' <<< "$o")" "playlists"

"$M" play album Fake al1 > /dev/null
grep -q "systemctl --user start --no-block torus-music.service" "$STUB_LOG" || fail "service started on demand"
for _ in $(seq 50); do
  st=$("$M" state 2>/dev/null || true)
  [[ $(j 'd.get("pos")' <<< "${st:-{\}}" 2>/dev/null) == 0 ]] && break
  sleep 0.1
done
assert_eq 2 "$(j 'len(d["queue"])' <<< "$st")" "queue has the album"
assert_eq 700 "$(stat -c %a "$XDG_RUNTIME_DIR/torus-music")" "run dir mode"
assert_eq 600 "$(stat -c %a "$XDG_RUNTIME_DIR/torus-music/ctl.sock")" "ctl socket mode"

mp() { gdbus call --session -d org.mpris.MediaPlayer2.torus_music -o /org/mpris/MediaPlayer2 -m org.freedesktop.DBus.Properties.Get "$1" "$2"; }
for _ in $(seq 50); do mp org.mpris.MediaPlayer2.Player Metadata 2>/dev/null | grep -q "Debut Song" && break; sleep 0.1; done
assert_contains <(mp org.mpris.MediaPlayer2 Identity) "torus music"
md=$(mp org.mpris.MediaPlayer2.Player Metadata)
assert_contains <(echo "$md") "Debut Song 1"
assert_contains <(echo "$md") "Björk Fake"
for _ in $(seq 40); do md=$(mp org.mpris.MediaPlayer2.Player Metadata); [[ $md == *artUrl* ]] && break; sleep 0.1; done
assert_contains <(echo "$md") "mpris:artUrl"
assert_contains <(echo "$md") "file://"
[[ $md == *xesam:url* || $md == *127.0.0.1* ]] && fail "stream address on the bus"

grep -q "^scrobble id=al1-s1 submission=true" "$F/server.log" && fail "scrobbled too early"
for _ in $(seq 100); do grep -q "^scrobble id=al1-s1 submission=true" "$F/server.log" && break; sleep 0.1; done
grep -q "^scrobble id=al1-s1 submission=false" "$F/server.log" || fail "now playing sent"
grep -q "^scrobble id=al1-s1 submission=true" "$F/server.log" || { tail -12 "$F/server.log" >&2; "$M" state >&2; fail "scrobble after half the track"; }
grep -q "plain-password" "$F/server.log" && fail "plain password sent"
grep -q "^stream id=al1-s1 format=raw" "$F/server.log" || fail "original format streamed"

row=$("$M" search morning local | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["tracks"]))')
"$M" next rows "$row" > /dev/null
"$M" move 1 0 > /dev/null
sleep 2
assert_eq 1 "$(grep -c "^scrobble id=al1-s1 submission=false" "$F/server.log")" "a queue edit is not a new track"
assert_eq 1 "$(grep -c "^scrobble id=al1-s1 submission=true" "$F/server.log")" "no second scrobble after a queue edit"
assert_eq "Debut Song 1" "$(j 'd["queue"][d["pos"]]["title"]' <<< "$("$M" state)")" "still the same track after the move"
"$M" remove 0 > /dev/null

python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); s.sendall(b"{\"cmd\":\"follow\"}\n"); time.sleep(30)' "$XDG_RUNTIME_DIR/torus-music/ctl.sock" > /dev/null 2>&1 &
STALL=$!
sleep 0.5
for _ in $(seq 40); do "$M" add album Fake al3 > /dev/null; done
t0=$(date +%s%N)
"$M" state > /dev/null || fail "state after a stalled follower"
(( ($(date +%s%N) - t0) / 1000000 < 3000 )) || fail "a follower that never reads froze the daemon"
kill $STALL 2> /dev/null
"$M" clear > /dev/null
"$M" play album Fake al1 > /dev/null

"$M" star > /dev/null
grep -q "^star id=al1-s" "$F/server.log" || fail "star sent"
st=$("$M" state)
assert_eq True "$(j 'd["queue"][d["pos"]]["starred"]' <<< "$st")" "queue knows the star"

"$M" pause > /dev/null
"$M" add album Fake al3 > /dev/null
assert_eq 4 "$(j 'len(d["queue"])' <<< "$("$M" state)")" "add appends"
row=$("$M" search morning local | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["tracks"]))')
"$M" next rows "$row" > /dev/null
st=$("$M" state)
assert_eq "Morning Song" "$(j 'd["queue"][d["pos"]+1]["title"]' <<< "$st")" "play next inserts after the current track"
[[ $st == *'"path"'* ]] && fail "state leaks local paths field"
"$M" move 1 3 > /dev/null
st=$("$M" state)
assert_eq "Morning Song" "$(j 'd["queue"][3]["title"]' <<< "$st")" "move"
"$M" remove 3 > /dev/null
assert_eq 4 "$(j 'len(d["queue"])' <<< "$("$M" state)")" "remove"

bad='[{"source":"local","id":"/etc/passwd","title":"x"},{"source":"Nope","id":"1"}]'
rc=0
"$M" add rows "$bad" > "$F/bad" || rc=$?
assert_eq 1 "$rc" "rows outside the library or from unknown servers refused"

ps -eo args > "$F/ps"
grep -q 'app-pass-123' "$F/ps" && fail "password in ps"
grep -qE 't=[0-9a-f]{32}' "$F/ps" && fail "token in ps"
grep -qE 'app-pass-123|t=[0-9a-f]{32}|/rest/' "$F/daemon.log" "$STUB_LOG" && fail "secret in logs"
grep -qE 'app-pass|/rest/' "$XDG_STATE_HOME/torus/music-queue.json" && fail "secret in the saved queue"

"$M" volume 0.4 > /dev/null
assert_eq 0.4 "$(j 'd["volume"]' <<< "$("$M" state)")" "the daemon keeps the music volume"
assert_contains <(mp org.mpris.MediaPlayer2.Player Volume) "0.4"
"$M" volume 7 > /dev/null
assert_eq 1.0 "$(j 'd["volume"]' <<< "$("$M" state)")" "volume clamped"
"$M" volume 0.3 > /dev/null
"$M" volume mute > /dev/null
"$M" jump 2 > /dev/null
"$M" seek 1 > /dev/null
"$M" pause > /dev/null
before=$(j 'd["pos"]' <<< "$("$M" state)")
assert_eq 2 "$before" "jump"
pkill -f "$F/bin/[t]orus-music daemon"
for _ in $(seq 30); do pgrep -f "input-ipc-server=$F/" > /dev/null || break; sleep 0.1; done
pgrep -f "input-ipc-server=$F/" > /dev/null && fail "mpv dies with the daemon"
"$M" toggle > /dev/null 2>&1 || true
"$M" pause > /dev/null
st=$("$M" state)
assert_eq 4 "$(j 'len(d["queue"])' <<< "$st")" "queue restored after a restart"
assert_eq "$before" "$(j 'd["pos"]' <<< "$st")" "position restored"
assert_eq "0.3 True" "$(j 'str(d["volume"]) + " " + str(d["muted"])' <<< "$st")" "volume restored after a restart"

cat > "$F/talk.py" <<'P'
import json, os, socket, sys, time
s = socket.socket(socket.AF_UNIX)
s.connect(os.environ["XDG_RUNTIME_DIR"] + "/torus-music/ctl.sock")
s.settimeout(8)
f = s.makefile("r", encoding="utf-8")
s.sendall((json.dumps({"rid": 1, "args": sys.argv[1:]}) + "\n").encode())
t0, res = time.monotonic(), {"answers": [], "covers": 0}
while True:
    m = json.loads(f.readline())
    if "cover" in m:
        res["covers"] += os.path.getsize(m["cover"]["path"]) > 0
        continue
    if m.get("rid") != 1:
        continue
    m["ms"] = round((time.monotonic() - t0) * 1000)
    res["answers"].append(m)
    if not m.get("more"):
        break
s.settimeout(1.2)
try:
    while "wait" in os.environ:
        m = json.loads(f.readline())
        res["covers"] += "cover" in m
except OSError:
    pass
print(json.dumps(res))
P
talk() { python3 "$F/talk.py" "$@"; }
rm -rf "$XDG_CACHE_HOME/torus/music/covers"
touch "$F/server.log.slow"
o=$(wait=1 talk albums all)
assert_eq "True False" "$(j '" ".join(str(a["more"]) for a in d["answers"])' <<< "$o")" "local albums first, the server follows"
assert_eq 2 "$(j 'len(d["answers"][0]["rows"])' <<< "$o")" "local albums without waiting for the server"
(( $(j 'd["answers"][0]["ms"]' <<< "$o") < 200 )) || fail "local albums waited for the server"
assert_eq 5 "$(j 'len(d["answers"][1]["rows"])' <<< "$o")" "both sources in the end"
assert_eq 0 "$(j 'len([r for r in d["answers"][1]["rows"] if r["source"] == "Fake" and r["cover"]])' <<< "$o")" "a list never waits for a cover"
assert_eq 3 "$(j 'd["covers"]' <<< "$o")" "covers land on their own"
before=$(grep -c "^connect" "$F/server.log")
o=$(talk albums all)
(( $(j 'd["answers"][0]["ms"]' <<< "$o") < 60 )) || fail "the second visit is not instant: $(j 'd["answers"][0]["ms"]' <<< "$o") ms"
assert_eq 5 "$(j 'len(d["answers"][0]["rows"])' <<< "$o")" "everything at once on the second visit"
[[ -s $(j '[r["cover"] for r in d["answers"][0]["rows"] if r["source"]=="Fake"][0]' <<< "$o") ]] || fail "cached cover in the list"
assert_eq 1 "$(j 'len(d["answers"])' <<< "$o")" "a fresh list is not asked for again"
for _ in 1 2 3; do talk search "debut $RANDOM" Fake > /dev/null; done
(( $(grep -c "^connect" "$F/server.log") - before <= 1 )) || fail "a new connection per request"
touch "$F/server.log.deaf"
o=$(talk search "post" Fake)
assert_eq "Post Song 1" "$(j 'd["answers"][-1]["tracks"][0]["title"]' <<< "$o")" "a connection that went silent is replaced"
ls "$XDG_RUNTIME_DIR"/torus-music/down-* > /dev/null 2>&1 && fail "a silent old connection marked the server offline"
rm "$F/server.log.deaf"
cat > "$F/two.py" <<'P'
import json, os, socket, time
s = socket.socket(socket.AF_UNIX)
s.connect(os.environ["XDG_RUNTIME_DIR"] + "/torus-music/ctl.sock")
s.settimeout(10)
f = s.makefile("r", encoding="utf-8")
t0 = time.monotonic()
for rid, args in ((1, ["add", "artist", "Fake", "ar1"]), (2, ["pause"])):
    s.sendall((json.dumps({"rid": rid, "args": args}) + "\n").encode())
at = {}
while len(at) < 2:
    m = json.loads(f.readline())
    if "rid" in m:
        at[m["rid"]] = round((time.monotonic() - t0) * 1000)
print(at[2], at[1])
P
read -r paused added < <(python3 "$F/two.py")
(( added > 900 && paused < 300 )) || fail "pause waited for a slow add: $paused ms, add $added ms"
o=$(talk search "cafe" all)
assert_eq "Morning Song" "$(j '[t["title"] for t in d["answers"][0]["tracks"] if "Morning" in t["title"]][0]' <<< "$o")" "local search answers first"
(( $(j 'd["answers"][0]["ms"]' <<< "$o") < 100 )) || fail "local search waited for the server"
o=$(talk open album Nope x)
assert_contains <(echo "$o") "no server named Nope"
o=$(talk login a b c)
assert_contains <(echo "$o") "bad request"
o=$(talk albums 7 8 9)
assert_contains <(echo "$o") "unknown list"
"$M" starset Fake al1-s2 1 > /dev/null
grep -q "^star id=al1-s2" "$F/server.log" || fail "starset sent"
for _ in $(seq 80); do [[ -s $XDG_CACHE_HOME/torus/music/browse.json ]] && break; sleep 0.1; done
assert_eq 600 "$(stat -c %a "$XDG_CACHE_HOME/torus/music/browse.json")" "cached lists mode"
grep -qE 'app-pass|t=[0-9a-f]{32}|/rest/|127.0.0.1' "$XDG_CACHE_HOME/torus/music/browse.json" && fail "secret or address in the cached lists"
pkill -f "$F/bin/[t]orus-music daemon"
for _ in $(seq 30); do pgrep -f "input-ipc-server=$F/" > /dev/null || break; sleep 0.1; done
"$M" pause > /dev/null
o=$(talk albums all)
assert_eq 5 "$(j 'len(d["answers"][0]["rows"])' <<< "$o")" "cached lists survive a restart"
(( $(j 'd["answers"][0]["ms"]' <<< "$o") < 150 )) || fail "first list after a restart waited for the server"
rm "$F/server.log.slow"

kill "$SRV"; SRV=
sleep 21
o=$(talk albums all)
assert_eq 5 "$(j 'len(d["answers"][-1].get("rows") or d["answers"][0]["rows"])' <<< "$o")" "an offline server keeps its last list"
assert_contains <(echo "$o") "Fake offline"
rm -f "$XDG_RUNTIME_DIR"/torus-music/down-*
start=$(date +%s)
home=$("$M" home)
(( $(date +%s) - start <= 6 )) || fail "offline server answered too slowly"
assert_contains <(echo "$home") "Fake offline"
assert_contains <(echo "$home") "Café Album"
start=$(date +%s)
"$M" home > /dev/null
(( $(date +%s) - start <= 2 )) || fail "down server is skipped for a minute"

"$M" logout Fake > /dev/null
assert_absent "$F/keyring/Fake"
echo "music ok"
