export function uriOf(path) {
    if (!path || path[0] !== "/")
        return ""
    return "file://" + path.split("/").map(p => encodeURIComponent(p)).join("/")
}

export function uriList(path) {
    const u = uriOf(path)
    return u === "" ? "" : u + "\r\n"
}
