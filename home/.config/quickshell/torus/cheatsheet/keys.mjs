const NAMES = {
    grave: "`", slash: "/", comma: ",", period: ".", minus: "-", equal: "=", space: "Space", escape: "Esc", delete: "Del",
    backspace: "Backspace", return: "↵", tab: "Tab", print: "Print", left: "←", right: "→", up: "↑", down: "↓",
    "mouse:272": "left drag", "mouse:273": "right drag", mouse_down: "scroll down", mouse_up: "scroll up",
    alt_l: "release", alt_r: "release", control: "Ctrl",
    xf86audiomute: "Mute", xf86audiomicmute: "Mic mute", xf86audiolowervolume: "Vol −", xf86audioraisevolume: "Vol +",
    xf86audioplay: "Play", xf86audiopause: "Pause", xf86audionext: "Next", xf86audioprev: "Prev",
    xf86monbrightnessup: "Bright +", xf86monbrightnessdown: "Bright −"
}

export function keyName(key) {
    const k = String(key || "")
    const n = NAMES[k.toLowerCase()]
    if (n)
        return n
    if (/^KP_/.test(k))
        return "Num " + k.slice(3)
    return k.length === 1 ? k.toUpperCase() : k
}

export function caps(modmask, key) {
    const out = []
    if (modmask & 64) out.push("Super")
    if (modmask & 4) out.push("Ctrl")
    if (modmask & 8) out.push("Alt")
    if (modmask & 1) out.push("Shift")
    out.push(keyName(key))
    return out
}

export function label(description) {
    const m = String(description || "").match(/^\[([^\]|]+)(?:\|([^\]]+))?\]\s*(.*)$/)
    if (!m)
        return null
    const what = m[3]
    const sub = (m[2] || "").toLowerCase()
    return { group: m[1], what: sub && /^(left|right|up|down|switch|cancel)$/.test(what) ? sub + ": " + what : what }
}

export function groups(binds, extra) {
    const by = {}
    const seen = {}
    for (const b of binds) {
        const l = label(b.description)
        if (!l || /workspace [0-9]/.test(b.description))
            continue
        const keys = caps(b.modmask, b.key)
        const id = l.group + "\n" + keys.join("+") + "\n" + l.what
        if (seen[id])
            continue
        seen[id] = true
        ;(by[l.group] = by[l.group] || []).push({ keys: keys, what: l.what, hay: (l.group + " " + keys.join(" ") + " " + b.key + " " + l.what).toLowerCase() })
    }
    return Object.keys(by).map(g => ({ name: g, items: by[g] })).concat(extra || [])
}

export function filter(all, query) {
    const words = String(query || "").toLowerCase().split(/\s+/).filter(w => w)
    if (!words.length)
        return all
    const out = []
    for (const g of all) {
        const items = g.items.filter(i => words.every(w => i.hay.includes(w)))
        if (items.length)
            out.push({ name: g.name, items: items })
    }
    return out
}
