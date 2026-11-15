import { test } from "node:test"
import assert from "node:assert/strict"
import * as U from "../../home/.config/quickshell/torus/components/fileuri.mjs"

test("a plain path becomes a file uri", () => {
    assert.equal(U.uriOf("/home/mmr/Pictures/Screenshots/torus-1.png"), "file:///home/mmr/Pictures/Screenshots/torus-1.png")
})

test("spaces, #, ? and non-ascii are encoded, slashes kept", () => {
    assert.equal(U.uriOf("/home/mmr/Videos/Clips/Hollow Knight/ace #1?.mp4"), "file:///home/mmr/Videos/Clips/Hollow%20Knight/ace%20%231%3F.mp4")
    assert.equal(U.uriOf("/tmp/über.png"), "file:///tmp/%C3%BCber.png")
})

test("the list ends with CRLF as text/uri-list wants", () => {
    assert.equal(U.uriList("/a/b"), "file:///a/b\r\n")
})

test("no path or a relative one gives nothing to drag", () => {
    assert.equal(U.uriOf(""), "")
    assert.equal(U.uriOf("relative/x.png"), "")
    assert.equal(U.uriList(""), "")
})
