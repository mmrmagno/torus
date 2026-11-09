#!/usr/bin/env python3
import json, socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); f = s.makefile('rw')
def cmd(c, a=None):
    f.write(json.dumps({"execute": c, **({"arguments": a} if a else {})}) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r: return r
f.readline(); cmd("qmp_capabilities")
def key(q, down): cmd("input-send-event", {"events": [{"type": "key", "data": {"down": down, "key": {"type": "qcode", "data": q}}}]})
# usage: qmp-keys.py QMP_SOCKET "alt+ 15 tab+ 15 alt- 10 tab-"  (qcode+ down, qcode- up, number = sleep ms)
for tok in sys.argv[2].split():
    if tok[-1] in "+-": key(tok[:-1], tok[-1] == "+")
    else: time.sleep(int(tok) / 1000)
