import { test } from "node:test"
import assert from "node:assert/strict"
import * as R from "../../home/.config/quickshell/torus/palette/route.mjs"

const P = [
    { key: "apps", prefix: "" }, { key: "calc", prefix: "=" }, { key: "files", prefix: "/" },
    { key: "recent", prefix: "r " }, { key: "kb", prefix: "?" }, { key: "ai", prefix: "!" },
    { key: "emoji", prefix: ":" }, { key: "colors", prefix: "#" }, { key: "timer", prefix: "t " },
    { key: "pass", prefix: "p " }, { key: "notifs", prefix: "n " }, { key: "projects", prefix: "d " },
    { key: "ssh", prefix: "s " }
]

test("every prefix routes to its scope with the rest as term", () => {
    const cases = [
        ["=2*21", "calc", "2*21"], ["/parity-needle", "files", "parity-needle"], ["/", "files", ""],
        ["r  notes ", "recent", "notes"], ["?parity needle", "kb", "parity needle"], ["?", "kb", ""],
        ["!why", "ai", "why"], [":grinning", "emoji", "grinning"], ["#ff8800", "colors", "ff8800"],
        ["t 5", "timer", "5"], ["t ", "timer", ""], ["p git", "pass", "git"], ["n discord", "notifs", "discord"],
        ["d torus", "projects", "torus"], ["s dock", "ssh", "dock"],
        ["kitt", "all", "kitt"], ["  night ", "all", "night"], ["t", "all", "t"], ["pass", "all", "pass"],
        ["rust", "all", "rust"], ["drive", "all", "drive"], ["", "all", ""]
    ]
    for (const [q, scope, term] of cases)
        assert.deepEqual([R.parse(q, P, "all").scope, R.parse(q, P, "all").term], [scope, term], q)
})

test("tab scope applies without a prefix, a typed prefix wins", () => {
    assert.equal(R.parse("git", P, "pass").scope, "pass")
    assert.equal(R.parse("git", P, "pass").term, "git")
    assert.equal(R.parse("=1+1", P, "pass").scope, "calc")
    assert.equal(R.parse("=1+1", P, "pass").prefix, "=")
    assert.equal(R.parse("git", P, "").scope, "all")
})

test("smart detection", () => {
    const math = ["2*21", "(3+4)/2", "2^10", "15%", "sqrt(2)", "5 km to mi", "20 usd in eur", "100 f to c", "1.5 + 2", "3x4", "-3 * 2", "2 - 5"]
    const notMath = ["42", "kitty", "night", "1password", "2fa codes", "x-wing", "c++", "steam_app_42", "t 5", "v2.0"]
    for (const m of math) assert.ok(R.detect(m).math, "math: " + m)
    for (const m of notMath) assert.ok(!R.detect(m).math, "not math: " + m)
    const paths = ["~/dev", "~/", "/etc/hosts", "/usr/share/"]
    const notPaths = ["/", "dev", "~", "/foo", "a/b"]
    for (const p of paths) assert.ok(R.detect(p).path, "path: " + p)
    for (const p of notPaths) assert.ok(!R.detect(p).path, "not path: " + p)
    const urls = [["https://example.com/x?y=1", "https://example.com/x?y=1"], ["http://localhost:5173", "http://localhost:5173"],
        ["www.archlinux.org", "https://www.archlinux.org"], ["github.com/mmrmagno/torus", "https://github.com/mmrmagno/torus"],
        ["marc-os.com", "https://marc-os.com"], ["localhost:8080", "http://localhost:8080"]]
    for (const [u, want] of urls) assert.equal(R.detect(u).url, want, "url: " + u)
    for (const u of ["kitty.conf", "README.md", "notes.txt", "hello world.com", "torus", "a.b"])
        assert.equal(R.detect(u).url, "", "not url: " + u)
})

test("hex colors normalize and convert", () => {
    assert.equal(R.hex("ff8800"), "#ff8800")
    assert.equal(R.hex("#F80"), "#ff8800")
    assert.equal(R.hex("ff88"), "")
    assert.equal(R.hex("zzzzzz"), "")
    assert.equal(R.rgb("#ff8800"), "rgb(255, 136, 0)")
    assert.equal(R.hsl("#ff8800"), "hsl(32, 100%, 50%)")
    assert.equal(R.hsl("#808080"), "hsl(0, 0%, 50%)")
})

test("score keeps the old weights", () => {
    assert.equal(R.score("kit", "Kitty"), 100)
    assert.equal(R.score("light", "Night light"), 70)
    assert.equal(R.score("ight", "Night light"), 40)
    assert.equal(R.score("ntl", "Night light"), 10)
    assert.equal(R.score("zz", "Night light"), 0)
    assert.equal(R.score("vsc", "Visual Studio Code"), 60)
    assert.equal(R.score("fire", "Power: performance"), 0)
    assert.equal(R.score("fire", "Forget this display layout"), 0)
    assert.equal(R.score("x", ""), 0)
})

test("rank orders by score, frecency and kind, drops misses", () => {
    const now = 1e12
    const items = [
        { id: "app:a", kind: "app", title: "Alacritty" }, { id: "w", kind: "window", title: "kitty", sub: "kitty · workspace 1" },
        { id: "app:k", kind: "app", title: "kitty" }, { id: "a:x", kind: "action", title: "Lock screen", keys: "kitty" }
    ]
    const r = R.rank(items, "kitt", {}, now)
    assert.deepEqual(r.map(x => x.it.id), ["w", "app:k", "a:x"])
    const f = { "app:k": { n: 3, t: now } }
    assert.deepEqual(R.rank(items, "kitt", f, now).map(x => x.it.id)[0], "app:k")
    assert.deepEqual(R.rank(items, "", {}, now).map(x => x.it.id), ["w", "app:a", "app:k", "a:x"], "empty term keeps order, kind bonus only")
    const same = [{ id: "b", title: "B" }, { id: "a", title: "A" }, { id: "c", title: "C" }]
    assert.deepEqual(R.rank(same, "", { c: { n: 1, t: now } }, now).map(x => x.it.id), ["c", "b", "a"], "empty term: frecency, then given order")
})

test("frecency halves every week, bump counts and prunes", () => {
    const now = 1e12, day = 86400000
    assert.equal(R.frecWeight({ n: 4, t: now }, now), 4)
    assert.ok(Math.abs(R.frecWeight({ n: 4, t: now - 7 * day }, now) - 2) < 1e-9)
    assert.equal(R.frecWeight(undefined, now), 0)
    let m = R.bump({}, "app:k", now)
    m = R.bump(m, "app:k", now + 1)
    assert.deepEqual(m["app:k"], { n: 2, t: now + 1 })
    let big = {}
    for (let i = 0; i < 250; i++) big = R.bump(big, "x" + i, now + i)
    assert.equal(Object.keys(big).length, 200)
    assert.ok(!("x0" in big) && "x249" in big)
    assert.deepEqual(R.fromCounts({ "app:k": 3 }, now), { "app:k": { n: 3, t: now } })
})

test("frecent picks only what still exists and never secrets", () => {
    const now = 1e12
    const f = { "app:k": { n: 5, t: now }, "gone": { n: 9, t: now }, "a:lock": { n: 2, t: now }, "p": { n: 9, t: now } }
    const pool = [{ id: "app:k", title: "kitty" }, { id: "a:lock", title: "Lock" }]
    assert.deepEqual(R.frecent(pool, f, now, 6).map(i => i.id), ["app:k", "a:lock"])
})

test("arrange keeps 4 per section, best section first, ties by order", () => {
    const rows = (k, ss) => ss.map((s, i) => ({ it: { id: k + i, title: k + i }, s }))
    const out = R.arrange([
        { section: "Apps", rows: rows("a", [50, 40, 30, 20, 10]) },
        { section: "Windows", rows: rows("w", [103]) },
        { section: "Actions", rows: rows("x", [50]) },
        { section: "SSH", rows: [] }
    ], 4)
    assert.deepEqual(out.map(i => i.section + ":" + i.id), ["Windows:w0", "Apps:a0", "Apps:a1", "Actions:x0"])
    const flat = R.arrange([{ section: "Apps", rows: rows("a", [50, 40, 30, 20, 16]) }], 4)
    assert.deepEqual(flat.map(i => i.id), ["a0", "a1", "a2", "a3"], "4 per section")
})

test("arrange drops weak fuzzy rows when something matches well", () => {
    const rows = (k, ss) => ss.map((s, i) => ({ it: { id: k + i, title: k + i }, s }))
    const out = R.arrange([
        { section: "Projects", rows: rows("p", [101]) },
        { section: "Apps", rows: rows("a", [12, 12]) },
        { section: "Actions", rows: rows("x", [41]) }
    ], 4)
    assert.deepEqual(out.map(i => i.id), ["p0", "x0"])
    const weak = R.arrange([{ section: "Apps", rows: rows("a", [12, 11]) }], 4)
    assert.equal(weak.length, 2, "only weak matches: keep them")
})
