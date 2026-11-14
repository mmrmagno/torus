#!/usr/bin/env python3
# usage: qmp-mouse.py QMP_SOCKET BOX_W BOX_H x,y ... click|down|up  (x,y in the layout bounding box)
import json,socket,sys,time
s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); f=s.makefile('rw')
def cmd(c,a=None):
    f.write(json.dumps({"execute":c,**({"arguments":a} if a else {})})+"\n"); f.flush()
    while True:
        r=json.loads(f.readline())
        if "return" in r or "error" in r: return r
f.readline(); cmd("qmp_capabilities")
W,H=float(sys.argv[2]),float(sys.argv[3])
for pt in sys.argv[4:]:
    if pt in ("down","up"):
        cmd("input-send-event",{"events":[{"type":"btn","data":{"down":pt=="down","button":"left"}}]}); time.sleep(0.15)
        continue
    if pt=="click":
        for d in (True,False):
            cmd("input-send-event",{"events":[{"type":"btn","data":{"down":d,"button":"left"}}]}); time.sleep(0.08)
        continue
    x,y=map(float,pt.split(','))
    cmd("input-send-event",{"events":[{"type":"abs","data":{"axis":"x","value":int(x/W*32767)}},{"type":"abs","data":{"axis":"y","value":int(y/H*32767)}}]})
    time.sleep(0.4)
