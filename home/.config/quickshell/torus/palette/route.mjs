export function parse(query, providers, tabScope) {
    for (const p of providers) {
        if (p.prefix && query.startsWith(p.prefix))
            return { scope: p.key, term: query.slice(p.prefix.length).trim(), prefix: p.prefix }
    }
    return { scope: tabScope || "all", term: query.trim(), prefix: "" }
}

const TLDS = "com|org|net|io|dev|ch|de|app|ai|gg|me|co|uk|eu|sh|xyz|info|tv"
const UNITS = /^-?\d[\d.,]*\s*[a-zA-Z°$€£]+\s+(to|in|as)\s+[a-zA-Z°$€£]+$/

export function detect(t) {
    const s = t.trim()
    const math = (/^[\d\s.,()+\-*/^%×÷x]+$/.test(s) && (/[\d.)]\s*[-+*/^×÷x]\s*[\d.(]/.test(s) || /^\d[\d.]*\s*%$/.test(s)))
        || /^(sqrt|cbrt|sin|cos|tan|log|ln|exp|abs|round|floor|ceil)\s*\(/.test(s) || UNITS.test(s)
    const path = /^(~\/|\/[^/\s]+\/)/.test(s)
    let url = ""
    if (/^https?:\/\/\S+$/.test(s))
        url = s
    else if (/^localhost(:\d+)?(\/\S*)?$/.test(s))
        url = "http://" + s
    else if (/^www\.[\w-]+(\.[\w-]+)+(\/\S*)?$/i.test(s) || new RegExp("^[\\w-]+(\\.[\\w-]+)*\\.(" + TLDS + ")(:\\d+)?(/\\S*)?$", "i").test(s))
        url = "https://" + s
    return { math: math, path: path, url: url }
}

export function hex(t) {
    const m = t.trim().toLowerCase().replace(/^#/, "")
    if (/^[0-9a-f]{6}$/.test(m))
        return "#" + m
    if (/^[0-9a-f]{3}$/.test(m))
        return "#" + m.split("").map(c => c + c).join("")
    return ""
}

function channels(h) {
    return [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16))
}

export function rgb(h) {
    return "rgb(" + channels(h).join(", ") + ")"
}

export function hsl(h) {
    const [r, g, b] = channels(h).map(v => v / 255)
    const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2
    let hue = 0, sat = 0
    if (max !== min) {
        const d = max - min
        sat = l > 0.5 ? d / (2 - max - min) : d / (max + min)
        hue = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4
        hue *= 60
    }
    return "hsl(" + Math.round(hue) + ", " + Math.round(sat * 100) + "%, " + Math.round(l * 100) + "%)"
}

export function score(q, s) {
    if (!s)
        return 0
    const t = s.toLowerCase()
    if (t.startsWith(q))
        return 100
    const i = t.indexOf(q)
    if (i > 0)
        return /[\s\-_.]/.test(t.charAt(i - 1)) ? 70 : 40
    if (q.length > 1) {
        const initials = t.split(/[\s\-_.:]+/).filter(w => w).map(w => w.charAt(0)).join("")
        let n = 0
        for (let k = 0; k < initials.length && n < q.length; k++)
            if (initials.charAt(k) === q.charAt(n))
                n++
        if (n === q.length)
            return 60
    }
    let j = 0, first = -1, last = -1
    for (let k = 0; k < t.length && j < q.length; k++) {
        if (t.charAt(k) !== q.charAt(j))
            continue
        if (first < 0)
            first = k
        last = k
        j++
    }
    return j === q.length && last - first < q.length * 2 + 1 ? 10 : 0
}

const WEEK = 7 * 86400000

export function frecWeight(e, now) {
    if (!e || !e.n)
        return 0
    return e.n * Math.pow(0.5, Math.max(0, now - e.t) / WEEK)
}

export function bump(map, id, now, max) {
    const out = Object.assign({}, map)
    const e = out[id]
    out[id] = { n: Math.min(100, (e ? e.n : 0) + 1), t: now }
    const keys = Object.keys(out)
    const limit = max || 200
    if (keys.length > limit) {
        keys.sort((a, b) => out[b].t - out[a].t)
        for (const k of keys.slice(limit))
            delete out[k]
    }
    return out
}

export function fromCounts(counts, now) {
    const out = {}
    for (const k in counts)
        if (counts[k] > 0)
            out[k] = { n: counts[k], t: now }
    return out
}

export function rank(items, q, frec, now) {
    const ql = q.toLowerCase()
    const scored = []
    let i = 0
    for (const it of items) {
        i++
        const base = ql === "" ? 1 : Math.max(score(ql, it.title), score(ql, it.sub) * 0.5, score(ql, it.keys) * 0.6)
        if (base <= 0)
            continue
        const boost = Math.min(30, 8 * frecWeight(frec[it.id], now))
        const kind = it.kind === "window" ? 3 : (it.kind === "app" ? 2 : 1)
        scored.push({ it: it, s: base + boost + kind, i: i })
    }
    scored.sort((a, b) => b.s - a.s || (ql === "" ? a.i - b.i : String(a.it.title).localeCompare(String(b.it.title))))
    return scored
}

export function frecent(pool, frec, now, max) {
    return pool.map(it => ({ it: it, w: frecWeight(frec[it.id], now) }))
        .filter(x => x.w > 0.05)
        .sort((a, b) => b.w - a.w)
        .slice(0, max)
        .map(x => x.it)
}

export function arrange(groups, limit) {
    let best = 0
    for (const g of groups)
        if (g.rows.length > 0)
            best = Math.max(best, g.rows[0].s)
    const floor = best * 0.3
    const kept = groups.map((g, i) => ({ g: g, i: i, rows: g.rows.filter(r => r.s >= floor).slice(0, limit) })).filter(x => x.rows.length > 0)
    kept.sort((a, b) => b.rows[0].s - a.rows[0].s || a.i - b.i)
    const out = []
    for (const k of kept)
        for (const r of k.rows)
            out.push(Object.assign({}, r.it, { section: k.g.section }))
    return out
}
