import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

// Page-level preview prefetcher. Downloads every preview of a response in ONE
// curl process (`--parallel`, single connection pool / keep-alive reuse) instead of
// spawning a bash+curl per image. Gelbooru previews need a Referer header (hotlink
// protection) which QML Image can't send, so they go through curl regardless.
Process {
    id: root

    signal finished()

    property var entries: []            // [{ url, path }]
    property string dir: ""
    property string referer: ""
    // Browser-like fallback: gelbooru rejects an empty User-Agent.
    property string userAgent: Config.options?.networking?.userAgent || "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"

    function _esc(s) {
        return StringUtils.shellSingleQuoteEscape(s);
    }

    function buildCommand() {
        if (!entries || entries.length === 0) return ["true"];
        const paths = entries.map(x => "'" + _esc(FileUtils.trimFileProtocol(x.path)) + "'").join(" ");
        const urls = entries.map(x => "'" + _esc(x.url) + "'").join(" ");
        const ua = userAgent ? " -A '" + _esc(userAgent) + "'" : "";
        const ref = referer ? " -H 'Referer: " + _esc(referer) + "'" : "";
        // Only fetch files that aren't already cached (and non-empty), then grab them
        // in one parallel curl. `-f` so an HTTP error (e.g. 403) isn't written to disk
        // as a bogus "preview" that would be taken for a cache hit on revisit.
        // `--parallel-max 6`: gelbooru's CDN refuses excess simultaneous connections
        // (they come back as `(35) TLS wrong version number` / `(28) connect timeout`),
        // so opening ~20 at once loses several per page. Capping concurrency inside the
        // one curl (with keep-alive reuse) stays under that limit → no dropped tiles.
        // Timeouts are a backstop; do NOT use --speed-time/--speed-limit (with --parallel
        // they misfire and add ~15s even on a fast transfer).
        const script =
            "paths=(" + paths + "); urls=(" + urls + "); " +
            "mkdir -p '" + _esc(dir) + "'; args=(); " +
            "for i in \"${!paths[@]}\"; do [ -s \"${paths[$i]}\" ] || args+=( -o \"${paths[$i]}\" \"${urls[$i]}\" ); done; " +
            "[ ${#args[@]} -gt 0 ] && curl -fsSL --parallel --parallel-max 6 --retry 2 --retry-connrefused --connect-timeout 10 --max-time 90" + ua + ref + " \"${args[@]}\"; exit 0";
        return ["bash", "-c", script];
    }

    running: false
    command: buildCommand()

    onExited: (code, status) => root.finished()
}
