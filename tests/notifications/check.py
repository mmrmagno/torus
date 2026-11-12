"""Run the real NotifCard pointer handlers in an offscreen quickshell."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[2]
source = repo / "home/.config/quickshell/torus"
if not shutil.which("quickshell"):
    print("SKIP: quickshell is not installed")
    raise SystemExit(0)

SHELL = r'''import QtQuick
import QtTest
import Quickshell
import qs
import qs.services
import qs.notifications
ShellRoot {
 id: root
 property int dismissed: 0
 property int hidden: 0
 property int invoked: 0
 function note(n, reply) {
  return {summary: "Title only", body: "<b> &nbsp; </b>", urgency: 1, appName: "app", appIcon: "", image: "", id: n,
   hasInlineReply: reply, inlineReplyPlaceholder: "", dismiss: () => root.dismissed++, sendInlineReply: t => {},
   actions: [{identifier: "default", text: "", invoke: () => root.invoked++}, {identifier: "x", text: " ", invoke: () => {}}]}
 }
 TestCase { id: test; when: false }
 NotifCard { id: otpCard; visible: false; width: 400; notif: ({summary: "GitHub", body: "Your verification code is 482 913.", urgency: 1, appName: "mail", appIcon: "", image: "", id: 90, hasInlineReply: false, actions: [], dismiss: () => {}}) }
 NotifCard { id: plainCard; visible: false; width: 400; notif: ({summary: "Order 1234567 shipped", body: "tracking 99887766", urgency: 1, appName: "shop", appIcon: "", image: "", id: 91, hasInlineReply: false, actions: [], dismiss: () => {}}) }
 FloatingWindow {
  visible: true
  implicitWidth: 440
  implicitHeight: 420
  NotifCard { id: card; x: 10; y: 10; width: 400; popup: true; notif: root.note(1, true); onDone: root.hidden++ }
  ListView {
   id: list
   x: 10; y: 140; width: 400; height: 200
   clip: true
   model: 6
   spacing: 6
   delegate: NotifCard { required property int index; width: 400; notif: root.note(10 + index, false) }
  }
 }
 function expect(ok, msg) { if (!ok) throw new Error(msg) }
 Timer {
  interval: 500
  running: true
  onTriggered: {
   try {
    expect(card.actions.length === 0 && !card.hasBody && card.defaultAction, "empty actions and body must be dropped")
    test.mouseClick(card, 90, 25, Qt.LeftButton)
    expect(root.invoked === 1, "title must run the default action")
    test.mouseClick(card, 30, 30, Qt.LeftButton)
    expect(root.invoked === 2, "icon must run the default action")
    test.mouseWheel(card, 50, 20, 0, 480, Qt.NoButton)
    expect(card.swipe === 0, "vertical wheel must not swipe")
    test.mouseWheel(card, 50, 20, -400, 0, Qt.NoButton)
    test.wait(600)
    expect(root.hidden >= 1 && root.dismissed === 0, "swiping a popup hides it and keeps it in history")
    const before = list.contentY
    for (let i = 0; i < 6; i++) {
     test.mouseWheel(list, 200, 100, 15, -120, Qt.NoButton)
     test.wait(20)
    }
    test.wait(400)
    expect(list.contentY > before, "a mostly vertical touchpad scroll must still scroll the list")
    expect(root.dismissed === 0, "a mostly vertical scroll must not dismiss a card")
    for (let i = 0; i < 8; i++) {
     test.mouseWheel(list, 200, 40, 60, 0, Qt.NoButton)
     test.wait(10)
    }
    test.wait(400)
    expect(root.dismissed === 1, "a horizontal swipe dismisses a centre card, got " + root.dismissed)
    card.popup = true
    card.swipe = 0
    test.wait(300)
    Notifs.openReply(card.notif)
    expect(Notifs.opened === "center" && Notifs.replyTarget === 1, "reply opens the centre aimed at the notification")
    expect(otpCard.code === "482913", "a verification code is found, got " + otpCard.code)
    expect(plainCard.code === "", "digits without a code word are not a code, got " + plainCard.code)
    console.log("NOTIFICATION_TESTS_PASSED")
   } catch (e) {
    console.log("NOTIFICATION_TESTS_FAILED " + e.message)
   }
   Qt.quit()
  }
 }
}
'''

STORE = '''pragma Singleton
import Quickshell
Singleton {
 property int cardsMade: 0
 property string lastOpen: ""
 function setOpen(name, value) { if (value) lastOpen = name }
}
'''

NOTIFS = '''pragma Singleton
import Quickshell
import qs
Singleton {
 property int lastAway: 0
 property var arrived: ({})
 property var repeats: ({})
 property var expanded: ({})
 property int replyTarget: -1
 property string opened: ""
 function hold(n) {}
 function ago(n) { return "now" }
 function dismissPopup(n) {}
 function openReply(n) { replyTarget = n.id; Store.setOpen("center", true); opened = Store.lastOpen }
 function copyOtp(code) {}
OTPOF
}
'''

with tempfile.TemporaryDirectory(prefix="torus-notification-test-") as directory:
    root = Path(directory)
    for rel in ("Theme.qml", "Feel.qml", "components/PanelButton.qml", "components/NotifIcon.qml", "notifications/NotifCard.qml"):
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / rel, root / rel)
    (root / "services").mkdir()
    (root / "Store.qml").write_text(STORE)
    real = (source / "services/Notifs.qml").read_text()
    start = real.index("    function otpOf(text) {")
    otpof = real[start:real.index("\n    }\n", start) + 6]
    (root / "services/Notifs.qml").write_text(NOTIFS.replace("OTPOF", otpof))
    (root / "shell.qml").write_text(SHELL)
    runtime = root / "runtime"
    runtime.mkdir(mode=0o700)
    env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "XDG_RUNTIME_DIR": str(runtime)}
    for key in ("WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "DBUS_SESSION_BUS_ADDRESS"):
        env.pop(key, None)
    try:
        result = subprocess.run(["quickshell", "-p", str(root), "--no-color"], env=env, capture_output=True, text=True, timeout=20)
    except subprocess.TimeoutExpired as exc:
        raise SystemExit("timed out\n" + (exc.stdout or b"").decode() + (exc.stderr or b"").decode())
    output = result.stdout + result.stderr
    if "NOTIFICATION_TESTS_PASSED" not in output:
        lines = [l for l in output.splitlines() if "FAILED" in l or "Error" in l or "error" in l]
        raise SystemExit("\n".join(lines) or output)
    print("PASS notification card")
