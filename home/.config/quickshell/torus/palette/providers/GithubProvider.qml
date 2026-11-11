import QtQuick
import Quickshell
import qs.services

Provider {
    id: root
    key: "github"
    name: "GitHub"
    glyph: "󰊤"
    prefix: "gh "
    help: "review requests, your pull requests with CI, failing main branches"

    function opened() {
        GitHub.refresh()
    }

    function row(id, glyph, title, sub, url, section) {
        return {
            id: id, kind: "github", glyph: glyph, title: title, sub: sub, section: section, enter: "open",
            act: () => GitHub.open(url),
            ctrl: { label: "copy link", act: () => Quickshell.execDetached(["wl-copy", "--", url]) }
        }
    }

    function results(term, scoped) {
        if (GitHub.status !== "ok" && GitHub.updated === 0)
            return [{ id: "gh:state", kind: "hint", glyph: "󰊤", title: GitHub.status === "signed-out" ? "gh is not signed in" : GitHub.status === "missing" ? "gh is not installed" : "loading GitHub…", sub: GitHub.status === "signed-out" ? "run gh auth login in a terminal" : "", act: () => {} }]
        const ci = c => c === "failure" || c === "error" ? "󰅚" : c === "pending" ? "󰔟" : c === "success" ? "󰄬" : "󰘬"
        return GitHub.review.map(p => row("gh:" + p.url, "󰈈", p.title, p.repo + " #" + p.number + "  ·  " + p.author, p.url, "Review requests"))
            .concat(GitHub.failing.map(r => row("gh:" + r.url, "󰅚", r.repo, r.branch + " is failing", r.url, "Failing")))
            .concat(GitHub.mine.map(p => row("gh:" + p.url, ci(p.ci), p.title, p.repo + " #" + p.number + (p.draft ? "  ·  draft" : "") + (p.ci ? "  ·  CI " + p.ci : ""), p.url, "My pull requests")))
    }
}
