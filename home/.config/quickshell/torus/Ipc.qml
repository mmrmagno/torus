import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io
import Quickshell.Services.UPower
import qs.services
import Quickshell.Hyprland

IpcHandler {
    target: "torus"

    function modules(): string {
        const out = []
        for (const s in Store.modules)
            out.push(s + ":" + Store.modules[s].join(","))
        return out.sort().join(";")
    }

    function barPreset(name: string): string {
        Store.setBarPreset(name)
        return Store.barPreset
    }

    function barToggle(): void {
        Store.barHidden = !Store.barHidden
    }

    function reload(): void {
        Quickshell.reload(false)
    }

    function reloadTheme(): void {
        Theme.reload()
    }

    function notifCount(): int {
        return Store.notifCount
    }

    function centerToggle(): void {
        Store.toggle("center")
    }

    function islandState(): string {
        const out = []
        for (const s in Island.modes)
            out.push(s + ":" + Island.modes[s])
        out.sort()
        out.unshift("state:" + Island.state)
        return out.join(";")
    }

    function lock(): string {
        Store.locked = true
        return "locked"
    }

    function donutClock(): string {
        return "t:" + DonutClock.ticks
    }

    function widgets(mode: string): string {
        Store.setWidgets(mode)
        return Store.widgets
    }

    function widgetsShown(): string {
        return Object.keys(Store.widgetsOn).filter(k => Store.widgetsOn[k]).sort().join(" ")
    }

    function clipToggle(): void {
        Store.toggle("clip")
    }

    function clipCount(): int {
        return Clip.shown.length
    }

    function clipFilter(text: string): void {
        Clip.filter = text
    }

    function agendaRefresh(): void {
        Agenda.refresh()
    }

    function agendaToday(): string {
        return Agenda.onDay(new Date()).map(e => e.start.slice(11) + " " + e.title).join("|")
    }

    function notifRepeatMax(): int {
        let m = 0
        for (const k in Notifs.repeats)
            m = Math.max(m, Notifs.repeats[k])
        return m
    }

    function quietSet(from: int, to: int): bool {
        Notifs.quietFrom = from
        Notifs.quietTo = to
        Notifs.checkQuiet()
        return Notifs.quietActive
    }

    function clipPin(index: int): void {
        Clip.togglePin(Clip.shown[index])
    }

    function clipPinned(): string {
        return Clip.pins.map(p => p.text).join("|")
    }

    function clipCopy(index: int): void {
        if (index >= 0 && index < Clip.shown.length)
            Clip.copy(Clip.shown[index])
    }

    function aiToggle(): void {
        Store.toggle("ai")
    }

    function aiRefresh(): void {
        Ai.refresh()
    }

    function aiStatus(): string {
        return Ai.status === "online" ? "online " + Ai.model + " " + Ai.models.join(",") : Ai.status
    }

    function aiAsk(text: string): void {
        Ai.reset()
        Ai.ask(text)
    }

    function aiError(): string {
        return Ai.error
    }

    function aiLast(): string {
        const m = Ai.messages
        return m.length > 0 ? m[m.length - 1].content : ""
    }

    function polkitState(): string {
        return Store.polkitState
    }

    function isLocked(): bool {
        return Store.lockSecure
    }

    function recordingsCount(): int {
        return Recordings.count
    }

    function islandFlash(kind: string, label: string): void {
        Island.flash(kind, { icon: "󰋼", label: label, value: -1, summary: label, body: "" }, 3000)
    }

    function notifGroups(): string {
        return Notifs.groups.map(g => g.app + ":" + g.items.length).join(";")
    }

    function notifThreads(): string {
        return Notifs.groups.map(g => g.app + ":" + g.threads.map(t => (t.notif.summary || "-") + "=" + (1 + t.earlier.length)).join(",")).join(";")
    }

    function notifCardsMade(): int {
        return Store.cardsMade
    }

    function notifReplyable(): int {
        return Notifs.list.filter(n => n.hasInlineReply).length
    }

    function clearNotifs(): void {
        Notifs.clearAll()
    }

    function popupCount(): int {
        return Notifs.popups.length
    }

    function clipsState(): string {
        return Store.clipsInfo
    }

    function gpuWatch(): string {
        return JSON.stringify(GpuWatch.last)
    }

    function polishState(): string {
        return JSON.stringify({ ocrEmpty: Store.ocrEmpty, fsMd: Theme.fsMd, dark: Theme.dark })
    }

    function settingsSheet(): string {
        return Store.sheetTitle
    }

    function quickLook(): string {
        return Store.look
    }

    function captureSelected(): string {
        return Store.captureSel
    }

    function popupsResting(): bool {
        return Store.popupsRest
    }

    function osdVisible(): bool {
        return Store.osdVisible
    }

    function logoutToggle(): void {
        Store.toggle("logout")
    }

    function wallpaper(mode: string): string {
        Store.setWallpaper(mode)
        return Store.wallpaper
    }

    function wallpaperNext(): string {
        Store.stepWallpaper(1)
        return Store.wallpaper
    }

    function wallpaperPrev(): string {
        Store.stepWallpaper(-1)
        return Store.wallpaper
    }

    function wallpaperList(): string {
        return Store.wallpapers.join("\n")
    }

    function donutFrames(screen: string): int {
        return Store.frames[screen] || 0
    }

    function donutLife(screen: string): string {
        return Store.life[screen] || ""
    }

    function donutPaused(state: bool): void {
        Store.donutPaused = state
    }

    function gamemode(state: bool): void {
        Store.gamemode = state
    }

    function dashboardToggle(): void {
        Store.toggle("dashboard")
    }

    function slideshowNext(): void {
        Slideshow.next()
    }

    function processesToggle(): void {
        Store.toggle("processes")
    }

    function ocrShow(): void {
        Store.setOpen("ocr", true)
    }

    function configErrors(): string {
        return HyprConfig.errors
    }

    function commuteState(): string {
        return JSON.stringify({ configured: Commute.configured, trips: Commute.connections.length, alerts: Commute.alertsOn, muted: Commute.alertMuted, busy: Commute.busy })
    }

    function commuteRefresh(): void {
        Commute.refresh()
    }

    function overviewToggle(): void {
        Store.toggle("overview")
    }

    function cheatSheetToggle(): void {
        Store.toggle("cheatsheet")
    }

    function altTabType(text: string): void {
        if (Store.altTabber && Store.isOpen("alttab"))
            Store.altTabber.type(Store.altTabber.query + text)
    }

    function altTab(dir: string): void {
        if (!Store.altTabber)
            return
        if (dir === "apply")
            Store.altTabber.apply()
        else if (dir === "cancel")
            Store.setOpen("alttab", false)
        else
            Store.altTabber.step(dir)
    }

    function rainCheck(): void {
        Weather.checkRain()
    }

    function weatherOk(): bool {
        return Weather.ok
    }

    function weatherRefresh(): void {
        Weather.refresh()
    }

    function fullscreenState(): string {
        return Object.keys(Fullscreen.full).sort().map(k => k + ":" + Fullscreen.full[k]).join(" ")
    }

    function visualizerFrames(): int {
        return Visualizer.frames
    }

    function lyricsCount(): int {
        return Lyrics.lines.length
    }

    function lyricsLine(): string {
        return Lyrics.line
    }

    function paletteToggle(): void {
        Store.toggle("palette")
    }

    function paletteOpen(scope: string): void {
        if (Store.isOpen("palette")) {
            if (Commands.mode === scope)
                Store.setOpen("palette", false)
            else
                Commands.setScope(scope)
            return
        }
        Commands.pendingScope = scope
        Store.setOpen("palette", true)
    }

    function paletteQuery(text: string): string {
        Store.setOpen("palette", true)
        Commands.query = text
        return Commands.mode
    }

    function paletteResults(): string {
        return Commands.results.slice(0, 5).map(r => r.kind + ":" + r.title).join("|")
    }

    function paletteRun(index: int): void {
        Commands.run(Commands.results[index])
    }

    function paletteRunWith(index: int, how: string): void {
        Commands.run(Commands.results[index], how)
    }

    function paletteRows(count: int): string {
        return Commands.results.slice(0, count).map(r => (r.section ? r.section + "/" : "") + r.kind + ":" + r.title).join("|")
    }

    function paletteSections(): string {
        const out = []
        for (const r of Commands.results) {
            const s = r.section || "-"
            if (out.length > 0 && out[out.length - 1][0] === s)
                out[out.length - 1][1]++
            else
                out.push([s, 1])
        }
        return out.map(x => x[0] + ":" + x[1]).join("|")
    }

    function paletteKeys(index: int): string {
        const r = Commands.results[index]
        return r ? [Commands.enterLabel(r), r.ctrl ? r.ctrl.label : "", r.alt ? r.alt.label : ""].join("|") : ""
    }

    function paletteSub(index: int): string {
        const r = Commands.results[index]
        return r ? r.sub || "" : ""
    }

    function devServers(): string {
        return DevServers.servers.map(s => s.port + ":" + s.comm).join("|")
    }

    function devServersRefresh(): void {
        DevServers.refresh()
    }

    function devServerStop(port: int): string {
        const s = DevServers.find(port)
        if (!s)
            return "none"
        DevServers.stop(s)
        return "stopping " + s.pid
    }

    function containers(): string {
        ContainerWatch.refresh()
        return ContainerWatch.list.map(c => c.engine + ":" + c.name).join("|")
    }

    function containerAct(name: string, what: string): string {
        const c = ContainerWatch.list.find(x => x.name === name)
        if (!c)
            return "none"
        ContainerWatch.act(c, what)
        return what + " " + c.engine + ":" + c.id
    }

    function controllers(): string {
        return UPower.devices.values.filter(d => d.type === UPowerDeviceType.GamingInput).map(d => d.model + "=" + Math.round(d.percentage * 100)).join("|")
    }

    function gamesToggle(): void {
        Store.toggle("games")
    }

    function homelabToggle(): void {
        Store.toggle("homelab")
    }

    function homelabState(): string {
        return (Spire.ok ? "ok" : "off") + ":" + Spire.problems + ":" + (Spire.data.nodes || []).length + ":" + (Spire.data.apps || []).length + ":" + Spire.amt.length
    }

    function githubState(): string {
        return GitHub.status + ":" + GitHub.review.length + ":" + GitHub.mine.length + ":" + GitHub.failing.length + ":" + GitHub.wanted
    }

    function githubRefresh(): void {
        GitHub.refresh()
    }

    function meetingState(): string {
        return (Meeting.active ? "active" : "idle") + " auto=" + Meeting.autoOn + " mic=" + InUse.mic + " cam=" + InUse.cam + " dnd=" + Store.dnd + " joined=" + Meeting.joined
    }

    function overlayToggle(): void {
        PerfOverlay.toggle()
    }

    function overlayState(): string {
        return (PerfOverlay.on ? "on" : "off") + " installed=" + PerfOverlay.installed
    }

    function devicesWatched(): bool {
        return DeviceWatch.startedAt > 0
    }

    function panelScreen(name: string): string {
        const s = Store.screenFor(name)
        return s ? s.name : ""
    }

    function setDnd(on: bool): void {
        Store.dnd = on
    }

    function meetingJoin(url: string): bool {
        return Meeting.joinCall(url)
    }

    function meetingNow(on: bool): void {
        if (on)
            Meeting.startNow()
        else
            Meeting.endNow()
    }

    function meetingAuto(on: bool): void {
        Meeting.setAuto(on)
    }

    function paletteMode(): string {
        return Commands.mode + ":" + Commands.term
    }

    function altTabSize(): string {
        const a = Store.altTabber
        return a ? a.cols + ":" + a.rows + ":" + a.implicitWidth + ":" + a.implicitHeight + ":" + (a.screen ? a.screen.width + "x" + a.screen.height : "?") : ""
    }

    function brightnessOsd(value: int): void {
        Island.flash("osd", { icon: "󰃟", label: value + "%", value: value / 100 }, 1600)
        Store.sound("tick")
    }

    function calmForce(on: bool): void {
        Calm.forced = on
    }

    function calmState(): string {
        return (Calm.active ? "on" : "off") + ":" + Calm.mode + ":" + (Calm.onBattery ? "battery" : "ac")
    }

    function batteryMode(mode: string): void {
        Calm.setMode(mode)
    }

    function feelSet(key: string, json: string): bool {
        try {
            Feel.set(key, JSON.parse(json))
            return true
        } catch (e) {
            return false
        }
    }

    function feelList(key: string, items: string): void {
        Feel.set(key, items.split(" ").filter(x => x !== ""))
    }

    function feelReset(): void {
        Feel.reset()
    }

    function feelState(): string {
        return JSON.stringify({ durMed: Theme.durMed, fsMd: Theme.fsMd, rPanel: Theme.rPanel, glass: Theme.glass, stayPut: Store.stayPut.indexOf("network") >= 0, music: Feel.islandOn("music"), notify: Feel.soundOn("notify") })
    }

    function stayAwake(on: bool): void {
        Store.stayAwake = on
    }

    function stayAwakeState(): bool {
        return Store.stayAwake
    }

    function captureToggle(): void {
        Store.toggle("capture")
    }

    function themeToggle(): void {
        Store.themeSection = ""
        Store.toggle("theme")
    }

    function themeOpen(section: string): void {
        if (Store.isOpen("theme") && Store.themeSection === section) {
            Store.setOpen("theme", false)
            return
        }
        Store.themeSection = section
        if (Store.isOpen("theme"))
            Store.setOpen("theme", false)
        Store.setOpen("theme", true)
    }

    function sessionToggle(): void {
        Store.toggle("session")
    }

    function sessionState(): string {
        return (Session.on ? "on" : "off") + " keep=" + Session.keep.length + " lost=" + Session.lost.length + " saved=" + Session.saved
    }

    function updatesToggle(): void {
        Store.toggle("updates")
    }

    function updatesState(): string {
        return Updates.count + ":" + Updates.news.length + ":" + Updates.unread
    }

    function torusState(): string {
        return (Updates.torusInstalled ? Updates.torusInstalled.hash : "") + ":" + Updates.torus.length + ":" + Updates.torusUnsigned
    }

    function networkState(): string {
        return (Wifi.wired || "-") + ":" + Wifi.enabled + ":" + Wifi.networks.length
    }

    function networkToggle(): void {
        Store.toggle("network")
    }

    function screenshotShow(path: string): void {
        Island.flash("shot", { path: path }, 6000)
    }

    function screenshotAct(what: string): bool {
        return Island.shotAct(what)
    }

    function trashUndo(): void {
        Island.trashUndo()
    }

    function soundTake(): string {
        const ev = Store.soundAsked
        Store.soundAsked = ""
        return ev
    }

    function mixerStreams(): string {
        return Store.mixerShown
    }

    function focusToggle(): void {
        if (Focus.running)
            Focus.stop()
        else
            Focus.start(25)
    }

    function focusStart(minutes: real): void {
        Focus.start(minutes)
    }

    function focusLeft(): int {
        return Focus.running ? Focus.left : -1
    }

    function dnd(): bool {
        return Store.dnd
    }

    function nightLight(): bool {
        return NightLight.on
    }

    function wallpaperOn(screen: string, mode: string): string {
        Store.setWallpaperFor(screen, mode)
        return Store.wallFor(screen)
    }

    function wallBreathe(on: bool): void {
        Store.setBreathing(on)
    }

    function notifMute(app: string, minutes: int): void {
        Notifs.mute(app, minutes)
    }

    function notifState(): string {
        return "count=" + Notifs.count + " groups=" + Notifs.groups.map(g => g.app + ":" + g.items.length).join(",") + " muted=" + Object.keys(Notifs.muted).filter(k => Notifs.isMuted(k)).join(",") + " away=" + Notifs.lastAway
    }

    function notifFilter(text: string): void {
        Notifs.filter = text
    }

    function capsCheck(): void {
        Island.checkCaps()
    }

    function timerStart(spec: string): string {
        const t = Timers.parse(spec)
        if (!t)
            return "bad"
        Timers.start(t.secs, t.label)
        return "ok " + t.secs
    }

    function timerState(): string {
        return Timers.running ? (Timers.stopwatch ? "stopwatch " : "timer ") + Timers.text + (Timers.paused ? " paused" : "") : "idle"
    }

    function timerStop(): void {
        Timers.stop()
    }

    function nightAuto(on: bool): void {
        NightLight.setAuto(on)
    }

    function nightState(): string {
        return (NightLight.on ? "on" : "off") + " auto=" + NightLight.auto + " phase=" + NightLight.phase + " " + NightLight.sunset + "-" + NightLight.sunrise
    }

    function nightLightToggle(): void {
        NightLight.toggle()
    }

    function isOpen(name: string): bool {
        return Store.isOpen(name)
    }

    function focusLabel(): string {
        return Store.focusLabel
    }

    function setFocusLabel(text: string): void {
        Store.focusLabel = text
    }

    function closeAll(): void {
        Store.closeAll("")
    }

    function barHeight(): int {
        return Store.barHeight
    }

    function clipManage(): void {
        if (Store.isOpen("clip") && Clip.manage) {
            Store.setOpen("clip", false)
            return
        }
        if (!Store.isOpen("clip"))
            Store.setOpen("clip", true)
        Clip.manage = true
    }

    function clipStats(): string {
        return JSON.stringify({ openMs: Clip.openMs, filterMs: Clip.filterMs, filterMax: Clip.filterMax, applyMs: Clip.applyMs, matches: Clip.matches, rows: Clip.rows.count, armed: Clip.armed, manage: Clip.manage, marked: Clip.markedCount })
    }

    function clipThumbs(): string {
        return JSON.stringify({ ready: Object.keys(Clip.thumbReady).length, queued: Clip.queue.length, decoding: Clip.decoderKey, images: Clip.entries.filter(e => e.image).length })
    }

    function clipText(index: int): string {
        const e = Clip.entryAt(index)
        return e ? e.text : ""
    }

    function clipReload(): void {
        Clip.reload()
    }

    function clipOrder(): string {
        const r = []
        for (let i = 0; i < Clip.rows.count; i++)
            r.push(Clip.rows.get(i).group + ":" + Clip.rows.get(i).text.slice(0, 14))
        return JSON.stringify({ rows: r, shown: Clip.shown.map(e => e.group + ":" + e.text.slice(0, 14)) })
    }

    function homelabKvm(): string {
        Spire.kvm()
        return "started"
    }

    function steamJobs(): string {
        return JSON.stringify(SteamLog.list.map(j => ({ kind: j.kind, appid: j.appid, name: j.name, pct: j.pct, left: j.left })))
    }

    function brightnessStep(dir: string): string {
        return Displays.step(dir) ? "ok" : "no"
    }

    function displaysState(): string {
        return JSON.stringify({ levels: Displays.levels, writes: Displays.writes, linked: Displays.linked, pending: Object.keys(Displays.pending).length, writing: Displays.writing })
    }

    function displaysSet(monitor: string, value: int): void {
        Displays.set(monitor, value)
    }

    function displaysSlide(monitor: string, from: int, to: int): void {
        for (let v = from; v <= to; v++)
            Displays.set(monitor, v)
    }

    function displaysRefresh(): void {
        Displays.refresh()
    }

    function deviceBatteryFeed(key: string, model: string, kind: string, pct: int): string {
        DeviceBattery.observe(key, model, kind, pct)
        return DeviceBattery.last
    }

    function deviceBatteryLast(): string {
        return DeviceBattery.last
    }

    function browserDownloads(): string {
        return JSON.stringify({ jobs: BrowserDownloads.list.map(j => j.name + ":" + j.size), last: BrowserDownloads.last })
    }

    function rulerShow(path: string): void {
        Store.rulerShot = path
        Store.setOpen("ruler", true)
    }

    function rulerMeasure(x1: int, y1: int, x2: int, y2: int, line: bool): string {
        const r = Store.rulerView
        if (!r || !Store.isOpen("ruler"))
            return "closed"
        r.lineMode = line
        r.a = Qt.point(x1, y1)
        r.b = Qt.point(x2, y2)
        r.finish()
        return Store.rulerLast
    }

    function rulerStraight(x1: int, y1: int, x2: int, y2: int): string {
        const r = Store.rulerView
        if (!r || !Store.isOpen("ruler"))
            return "closed"
        r.lineMode = true
        r.straight = true
        r.a = Qt.point(x1, y1)
        r.raw = Qt.point(x2, y2)
        r.track()
        r.straight = false
        r.finish()
        return Store.rulerLast + "@" + r.b.x + "," + r.b.y
    }

    function rulerColorAt(x: int, y: int): string {
        const r = Store.rulerView
        if (!r || !Store.isOpen("ruler"))
            return "closed"
        r.sample(x, y)
        return r.hex
    }

    function widgetsQuiet(on: bool): void {
        Store.widgetsQuiet = on
    }
}
