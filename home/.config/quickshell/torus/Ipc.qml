import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io
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

    function donutPaused(state: bool): void {
        Store.donutPaused = state
    }

    function gamemode(state: bool): void {
        Store.gamemode = state
    }

    function dashboardToggle(): void {
        Store.toggle("dashboard")
    }

    function overviewToggle(): void {
        Store.toggle("overview")
    }

    function cheatSheetToggle(): void {
        Store.toggle("cheatsheet")
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

    function altTabSize(): string {
        const a = Store.altTabber
        return a ? a.cols + ":" + a.rows + ":" + a.implicitWidth + ":" + a.implicitHeight + ":" + (a.screen ? a.screen.width + "x" + a.screen.height : "?") : ""
    }

    function brightnessOsd(value: int): void {
        Island.flash("osd", { icon: "󰃟", label: value + "%", value: value / 100 }, 1600)
    }

    function updatesToggle(): void {
        Store.toggle("updates")
    }

    function updatesState(): string {
        return Updates.count + ":" + Updates.news.length + ":" + Updates.unread
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

    function mixerStreams(): string {
        return Pipewire.nodes.values.filter(n => n.audio && n.isStream && n.isSink).map(n => ((n.properties || {})["application.name"] || n.name) + "=" + Math.round(n.audio.volume * 100)).join("|")
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

    function nightLightToggle(): void {
        NightLight.toggle()
    }

    function isOpen(name: string): bool {
        return Store.isOpen(name)
    }
}
