import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

// Page-level preview prefetcher. Downloads every preview of a response in ONE
// curl process (parallel, single connection pool) instead of spawning a bash+curl
// per image. Gelbooru previews need a Referer header (hotlink protection), which
// QML Image can't send, so they must go through curl regardless.
Process {
    id: root

    signal finished()

    property var entries: []            // [{ url, path }]
    property string dir: ""
    property string referer: ""
    property string userAgent: Config.options?.networking?.userAgent ?? ""

    function _esc(s) {
        return StringUtils.shellSingleQuoteEscape(s);
    }

    function buildCommand() {
        if (!entries || entries.length === 0) return ["true"];
        const paths = entries.map(e => "'" + _esc(FileUtils.trimFileProtocol(e.path)) + "'").join(" ");
        const urls = entries.map(e => "'" + _esc(e.url) + "'").join(" ");
        const ua = userAgent ? " -A '" + _esc(userAgent) + "'" : "";
        const ref = referer ? " -H 'Referer: " + _esc(referer) + "'" : "";
        // Only fetch files that aren't already cached, then grab them all in parallel.
        const script =
            "paths=(" + paths + "); urls=(" + urls + "); " +
            "mkdir -p '" + _esc(dir) + "'; args=(); " +
            "for i in \"${!paths[@]}\"; do [ -f \"${paths[$i]}\" ] || args+=( -o \"${paths[$i]}\" \"${urls[$i]}\" ); done; " +
            "[ ${#args[@]} -gt 0 ] && curl -sSL --parallel" + ua + ref + " \"${args[@]}\"; exit 0";
        return ["bash", "-c", script];
    }

    running: false
    command: buildCommand()

    onExited: (code, status) => root.finished()
}
