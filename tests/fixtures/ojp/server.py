import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

LIR = """<?xml version="1.0"?><OJP xmlns="http://www.vdv.de/ojp" xmlns:siri="http://www.siri.org.uk/siri"><OJPResponse><siri:ServiceDelivery>
<OJPLocationInformationDelivery><PlaceResult><Place><StopPlace><StopPlaceRef>8503000</StopPlaceRef></StopPlace><Name><Text>Zuerich HB</Text></Name>
<GeoPosition><siri:Longitude>8.54</siri:Longitude><siri:Latitude>47.37</siri:Latitude></GeoPosition></Place></PlaceResult></OJPLocationInformationDelivery>
</siri:ServiceDelivery></OJPResponse></OJP>"""

TRIP = """<?xml version="1.0"?><OJP xmlns="http://www.vdv.de/ojp" xmlns:siri="http://www.siri.org.uk/siri"><OJPResponse><siri:ServiceDelivery>
<OJPTripDelivery><TripResult><Trip><StartTime>2026-11-11T07:05:00+01:00</StartTime><EndTime>2026-11-11T07:52:00+01:00</EndTime><Transfers>0</Transfers>
<Leg><TransferLeg><Duration>PT4M</Duration></TransferLeg></Leg>
<Leg><TimedLeg><LegBoard><StopPointName><Text>Home</Text></StopPointName><PlannedQuay><Text>7</Text></PlannedQuay>
<ServiceDeparture><TimetabledTime>2026-11-11T07:09:00+01:00</TimetabledTime><EstimatedTime>2026-11-11T07:11:00+01:00</EstimatedTime></ServiceDeparture></LegBoard>
<LegAlight><StopPointName><Text>Work</Text></StopPointName><ServiceArrival><TimetabledTime>2026-11-11T07:52:00+01:00</TimetabledTime></ServiceArrival></LegAlight>
<Service><PublishedServiceName><Text>IC 8</Text></PublishedServiceName><DestinationText><Text>Brig</Text></DestinationText></Service></TimedLeg></Leg>
</Trip></TripResult></OJPTripDelivery></siri:ServiceDelivery></OJPResponse></OJP>"""


def shifted(xml, base):
    import re
    from datetime import datetime, timedelta
    t0 = datetime.fromisoformat("2026-11-11T07:00:00+01:00")
    now = datetime.fromtimestamp(base).astimezone()
    return re.sub(r"2026-11-11T(\d\d:\d\d:\d\d)\+01:00",
                  lambda m: (now + (datetime.fromisoformat("2026-11-11T" + m.group(1) + "+01:00") - t0)).isoformat(timespec="seconds"), xml)


BASE = float(sys.argv[2]) if len(sys.argv) > 2 else 0


class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode()
        if self.headers.get("Authorization") != "Bearer test-key":
            self.send_response(401)
            self.end_headers()
            return
        out = LIR if "OJPLocationInformationRequest" in body else (shifted(TRIP, BASE) if BASE else TRIP)
        self.send_response(200)
        self.send_header("Content-Type", "application/xml")
        self.end_headers()
        self.wfile.write(out.encode())

    def log_message(self, *a):
        pass


HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
