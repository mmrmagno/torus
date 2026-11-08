import QtQuick
import Quickshell
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

    function isOpen(name: string): bool {
        return Store.isOpen(name)
    }
}
