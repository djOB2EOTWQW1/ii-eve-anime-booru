import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland

Button {
    id: root
    property var imageData
    property var rowHeight
    // Settings store (JsonAdapter) threaded from Anime.qml; read-only here.
    property var settings: null
    property bool manualDownload: false
    property string previewDownloadPath
    property string downloadPath
    property string nsfwPath
    property string fileName: {
        const url = imageData.file_url ?? ""
        return decodeURIComponent(url.substring(url.lastIndexOf('/') + 1))
    }
    property string fileExt: {
        const ext = (imageData.file_ext ?? "").toLowerCase().replace(/^\./, "")
        if (ext) return ext
        const url = (imageData.file_url ?? "").split("?")[0]
        return url.substring(url.lastIndexOf(".") + 1).toLowerCase()
    }
    property bool isPlayable: ["mp4", "webm", "m4v", "mov", "gif"].includes(root.fileExt)
    // Real videos can't render as a static Image, so always thumbnail them regardless of quality
    readonly property bool isStaticVideo: ["mp4", "webm", "m4v", "mov"].includes(root.fileExt)
    readonly property string previewQuality: settings?.previewQuality ?? Config.options?.sidebar?.booru?.previewQuality ?? "preview"
    readonly property string resolvedPreviewUrl: {
        if (root.isStaticVideo)
            return imageData.preview_url ?? imageData.sample_url ?? imageData.file_url
        if (root.previewQuality === "full")
            return imageData.file_url ?? imageData.sample_url ?? imageData.preview_url
        if (root.previewQuality === "sample")
            return imageData.sample_url ?? imageData.file_url ?? imageData.preview_url
        return imageData.preview_url ?? imageData.sample_url ?? imageData.file_url
    }
    property string previewCacheName: {
        const url = (root.resolvedPreviewUrl ?? "").split("?")[0]
        return decodeURIComponent(url.substring(url.lastIndexOf('/') + 1))
    }
    property string filePath: `${root.previewDownloadPath}/${root.previewCacheName}`

    // Manual-provider previews are downloaded a page at a time by BooruPagePrefetch
    // (one `curl --parallel` with referer). To stay responsive the tile does NOT wait
    // for the whole page: it polls for ITS OWN file and shows it the moment that file
    // lands (progressive), so one slow/stalled sibling can't blank the rest.
    property bool previewsReady: false      // page prefetch finished (from parent)
    property int _retries: 0
    readonly property int _maxRetries: 80   // poll ceiling (~80 × 500ms)
    property string _displaySource: ""      // imperatively driven for manual providers

    property bool nativePlaying: false
    property int maxTagStringLineLength: 50
    property real imageRadius: Appearance.rounding.small
    property var tagInputField

    property bool showActions: false
    property bool showTags: false

    // Re-point the Image at our cache file (toggle through "" so Qt re-reads from disk
    // even if the path is unchanged). Used to poll for the page-curl's output.
    function _reloadPreview() {
        root._displaySource = ""
        Qt.callLater(() => { root._displaySource = root.filePath })
    }
    Component.onCompleted: if (root.manualDownload) root._reloadPreview()
    onFilePathChanged: if (root.manualDownload) { root._retries = 0; root._reloadPreview() }
    // Prefetch finished → one final attempt for files that landed right at the end.
    onPreviewsReadyChanged: if (root.manualDownload && root.previewsReady) root._reloadPreview()

    Timer { // Poll for this tile's file while the page prefetch is still downloading.
        id: filePoll
        interval: 500
        repeat: true
        onTriggered: {
            if (imageObject.status === Image.Ready) { stop(); return }
            if (root.previewsReady) { stop(); return }   // prefetch done; file won't appear
            if (root._retries++ >= root._maxRetries) { stop(); return }
            root._reloadPreview()
        }
    }

    padding: 0
    implicitWidth: root.rowHeight * modelData.aspect_ratio
    implicitHeight: root.rowHeight

    background: Rectangle {
        implicitWidth: root.rowHeight * modelData.aspect_ratio
        implicitHeight: root.rowHeight
        radius: imageRadius
        color: Appearance.colors.colLayer2
    }

    contentItem: Item {
        anchors.fill: parent

        StyledImage {
            id: imageObject
            anchors.fill: parent
            width: root.rowHeight * modelData.aspect_ratio
            height: root.rowHeight
            fillMode: Image.PreserveAspectFit
            // Manual providers: poll-driven local file (_displaySource). Others: the
            // remote URL directly.
            source: root.manualDownload ? root._displaySource : root.resolvedPreviewUrl
            onStatusChanged: {
                if (!root.manualDownload) return
                if (status === Image.Ready) { filePoll.stop(); return }
                if (status === Image.Error) {
                    // prefetch done & still no file → give up (blank). Otherwise the
                    // file isn't written yet → keep polling until it lands.
                    if (!root.previewsReady && !filePoll.running && root._retries < root._maxRetries) {
                        filePoll.start()
                    }
                }
            }

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: root.rowHeight * modelData.aspect_ratio
                    height: root.rowHeight
                    radius: imageRadius
                }
            }
        }

        MaterialLoadingIndicator { // Preview loading spinner
            anchors.centerIn: parent
            // Needs an explicit size — defaults to 0 (invisible) otherwise.
            implicitSize: Math.round(Math.max(20, Math.min(48, root.rowHeight * 0.35)))
            // Spinner while this tile is still waiting for its file (manual, not yet
            // loaded and prefetch not done) or while the Image is loading. Once the
            // tile loads it disappears independently — progressive, not all-or-nothing.
            visible: (root.manualDownload && imageObject.status !== Image.Ready && !root.previewsReady)
                     || imageObject.status === Image.Loading
            loading: visible
        }

        Rectangle { // Hover scrim
            anchors.fill: parent
            radius: root.imageRadius
            visible: actionRow.opacity > 0
            gradient: Gradient {
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1.0; color: ColorUtils.transparentize(Appearance.m3colors.m3surface, 0.4) }
            }
            opacity: actionRow.opacity
        }

        RowLayout { // Hover action row
            id: actionRow
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 8
            }
            spacing: 6
            opacity: (!root.nativePlaying && (root.hovered || root.showTags)) ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            component ImgActionButton: RippleButton {
                id: actionBtn
                implicitWidth: 30
                implicitHeight: 30
                padding: 0
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.m3colors.m3surface, 0.3)
                colBackgroundHover: ColorUtils.transparentize(ColorUtils.mix(Appearance.m3colors.m3surface, Appearance.m3colors.m3onSurface, 0.8), 0.2)
                colRipple: ColorUtils.transparentize(ColorUtils.mix(Appearance.m3colors.m3surface, Appearance.m3colors.m3onSurface, 0.6), 0.1)
                property string symbolName: ""
                property color symbolColor: Appearance.m3colors.m3onSurface
                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: actionBtn.symbolName
                    iconSize: Appearance.font.pixelSize.large
                    color: actionBtn.symbolColor
                }
            }

            ImgActionButton { // Play
                symbolName: "play_arrow"
                visible: root.isPlayable
                onClicked: {
                    // gelbooru needs a Referer header the native player can't send → force mpv
                    const useNative = (root.settings?.player ?? Config.options?.sidebar?.booru?.player ?? "mpv") === "native"
                        && !root.imageData.file_url.includes("gelbooru.com")
                    if (useNative) {
                        root.nativePlaying = true
                        return
                    }
                    const userAgent = Config.options?.networking?.userAgent ?? ""
                    const args = ["mpv", "--force-window=immediate", "--cache=yes", "--loop-file=inf"]
                    if (userAgent) args.push(`--user-agent=${userAgent}`)
                    if (root.imageData.file_url.includes("gelbooru.com"))
                        args.push(`--referrer=https://gelbooru.com/index.php?page=post&s=view&id=${root.imageData.id}`)
                    args.push(root.imageData.file_url)
                    Quickshell.execDetached(args)
                }
            }

            ImgActionButton { // Download
                symbolName: "download"
                onClicked: {
                    const targetPath = root.imageData.is_nsfw ? root.nsfwPath : root.downloadPath;
                    const isGelbooru = root.imageData.file_url.includes("gelbooru.com");
                    const refererHeader = isGelbooru ?
                        `-H "Referer: https://gelbooru.com/index.php?page=post&s=view&id=${root.imageData.id}"` : "";
                    const userAgent = Config.options?.networking?.userAgent ?? ""
                    const userAgentHeader = userAgent ? ` -H 'User-Agent: ${StringUtils.shellSingleQuoteEscape(userAgent)}'` : ""
                    Quickshell.execDetached(["bash", "-c",
                        `mkdir -p '${targetPath}' && curl ${refererHeader}${userAgentHeader} '${StringUtils.shellSingleQuoteEscape(root.imageData.file_url)}' -o '${targetPath}/${root.fileName}' && notify-send '${Translation.tr("Download complete")}' '${root.downloadPath}/${root.fileName}' -a 'Shell'`
                    ])
                }
            }

            ImgActionButton { // Open source / link
                symbolName: "open_in_new"
                onClicked: {
                    const url = (root.imageData.source && root.imageData.source.length > 0)
                        ? root.imageData.source : root.imageData.file_url
                    Hyprland.dispatch("hl.config({cursor = {no_warps = true}})")
                    Qt.openUrlExternally(url)
                    Hyprland.dispatch("hl.config({cursor = {no_warps = false}})")
                }
            }

            Item { Layout.fillWidth: true }

            ImgActionButton { // Favorite
                symbolName: "favorite"
                // Boolean() guards against an undefined result, which QML can't assign to
                // bool and would silently leave visible at its default (true).
                visible: Boolean((root.imageData.file_url?.includes("gelbooru.com") && KeyringStorage.keyringData?.apiKeys?.["gelbooru_pass_hash"]) ||
                    (root.imageData.file_url?.includes("donmai.us") && KeyringStorage.keyringData?.apiKeys?.["danbooru"] && KeyringStorage.keyringData?.apiKeys?.["danbooru_user_id"]))
                onClicked: {
                    const postId = root.imageData.id;
                    if (root.imageData.file_url.includes("gelbooru.com")) {
                        const cookieString = `user_id=${KeyringStorage.keyringData?.apiKeys?.["gelbooru_user_id"] || ""}; pass_hash=${KeyringStorage.keyringData?.apiKeys?.["gelbooru_pass_hash"] || ""}; post_threshold=0`;
                        Quickshell.execDetached(["bash", "-c",
                            `response=$(curl -s -H 'Referer: https://gelbooru.com/index.php?page=post&s=view&id=${postId}' -b '${cookieString}' 'https://gelbooru.com/public/addfav.php?id=${postId}'); if [ "$response" = "1" ] || [ "$response" = "3" ]; then notify-send '✅ Added to favorites' 'Post #${postId}' -a 'Shell'; else notify-send '❌ Failed to add' "Post #${postId} (response: $response)" -a 'Shell'; fi`
                        ]);
                    } else if (root.imageData.file_url.includes("donmai.us")) {
                        const login = KeyringStorage.keyringData?.apiKeys?.["danbooru_user_id"];
                        const apiKey = KeyringStorage.keyringData?.apiKeys?.["danbooru"];
                        if (!login || !apiKey) {
                            Quickshell.execDetached(["notify-send", "❌ Failed to add", `Post #${postId} (no Danbooru API key)`, "-a", "Shell"]);
                            return;
                        }
                        Quickshell.execDetached(["bash", "-c",
                            `code=$(curl -s -o /dev/null -w '%{http_code}' -A 'Quickshell-Booru/1.0' -X POST "https://danbooru.donmai.us/favorites.json?login=${login}&api_key=${apiKey}" -d "post_id=${postId}"); case "$code" in 200|201) notify-send '✅ Added to favorites' 'Post #${postId}' -a 'Shell';; 422) notify-send 'Already in favorites' 'Post #${postId}' -a 'Shell';; *) notify-send '❌ Failed to add' "Post #${postId} (HTTP $code)" -a 'Shell';; esac`
                        ]);
                    }
                }
            }

            ImgActionButton { // Tags
                symbolName: "sell"
                symbolColor: root.showTags ? Appearance.colors.colOnPrimary : Appearance.m3colors.m3onSurface
                colBackground: root.showTags ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.m3colors.m3surface, 0.3)
                onClicked: root.showTags = !root.showTags
            }
        }

        Loader { // Tags overlay
            anchors.fill: parent
            active: root.showTags
            sourceComponent: ImageTagsOverlay {
                tagsString: root.imageData.tags
                cornerRadius: root.imageRadius
                tagInputField: root.tagInputField
                onCloseRequested: root.showTags = false
            }
        }

        Loader { // Native video player
            anchors.fill: parent
            active: root.nativePlaying
            sourceComponent: BooruVideoPlayer {
                source: root.imageData.file_url
                cornerRadius: root.imageRadius
                onCloseRequested: root.nativePlaying = false
            }
        }
    }
}
