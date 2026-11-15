import sys
from gi.repository import Gio, GLib

ART = sys.argv[1] if len(sys.argv) > 1 else "https://127.0.0.1:9/cover.jpg"
XML = """<node>
<interface name="org.mpris.MediaPlayer2">
  <property name="Identity" type="s" access="read"/>
  <property name="CanQuit" type="b" access="read"/>
  <property name="CanRaise" type="b" access="read"/>
  <property name="HasTrackList" type="b" access="read"/>
  <property name="SupportedUriSchemes" type="as" access="read"/>
  <property name="SupportedMimeTypes" type="as" access="read"/>
</interface>
<interface name="org.mpris.MediaPlayer2.Player">
  <property name="PlaybackStatus" type="s" access="read"/>
  <property name="Metadata" type="a{sv}" access="read"/>
  <property name="Position" type="x" access="read"/>
  <property name="Volume" type="d" access="read"/>
  <property name="CanPlay" type="b" access="read"/>
  <property name="CanPause" type="b" access="read"/>
  <property name="CanGoNext" type="b" access="read"/>
  <property name="CanGoPrevious" type="b" access="read"/>
  <property name="CanSeek" type="b" access="read"/>
  <property name="CanControl" type="b" access="read"/>
  <method name="PlayPause"/><method name="Play"/><method name="Pause"/><method name="Stop"/>
  <method name="Next"/><method name="Previous"/>
</interface>
</node>"""

PROPS = {
    "Identity": GLib.Variant("s", "Parity Player"), "CanQuit": GLib.Variant("b", False),
    "CanRaise": GLib.Variant("b", False), "HasTrackList": GLib.Variant("b", False),
    "SupportedUriSchemes": GLib.Variant("as", []), "SupportedMimeTypes": GLib.Variant("as", []),
    "PlaybackStatus": GLib.Variant("s", "Playing"), "Position": GLib.Variant("x", 0), "Volume": GLib.Variant("d", 1.0),
    "Metadata": GLib.Variant("a{sv}", {
        "mpris:trackid": GLib.Variant("o", "/org/parity/track/1"), "mpris:length": GLib.Variant("x", 200000000),
        "xesam:title": GLib.Variant("s", "Parity Song"), "xesam:artist": GLib.Variant("as", ["Parity"]),
        "mpris:artUrl": GLib.Variant("s", ART)}),
}
for k in ("CanPlay", "CanPause", "CanGoNext", "CanGoPrevious", "CanSeek", "CanControl"):
    PROPS[k] = GLib.Variant("b", True)

def get_prop(conn, sender, path, iface, name):
    return PROPS[name]

def call(conn, sender, path, iface, method, params, inv):
    inv.return_value(None)

bus = Gio.bus_get_sync(Gio.BusType.SESSION)
info = Gio.DBusNodeInfo.new_for_xml(XML)
for i in info.interfaces:
    bus.register_object("/org/mpris/MediaPlayer2", i, call, get_prop, None)
Gio.bus_own_name_on_connection(bus, "org.mpris.MediaPlayer2.parity", Gio.BusNameOwnerFlags.NONE, None, None)
GLib.MainLoop().run()
