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
    readonly property string previewQuality: ExtensionManager.getExtensionConfig("ii-eve-anime-booru", "previewQuality", Config.options?.sidebar?.booru?.previewQuality ?? "preview")
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
    // Set by the parent response once its page-level prefetch has finished.
    property bool previewsReady: false
    property bool nativePlaying: false
    property int maxTagStringLineLength: 50
    property real imageRadius: Appearance.rounding.small
    property var tagInputField

    property bool showActions: false
    property bool showTags: false

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
            source: root.manualDownload ? (root.previewsReady ? root.filePath : "") : root.resolvedPreviewUrl

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: root.rowHeight * modelData.aspect_ratio
                    height: root.rowHeight
                    radius: imageRadius
                }
            }
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
                    const useNative = ExtensionManager.getExtensionConfig("ii-eve-anime-booru", "player", Config.options?.sidebar?.booru?.player ?? "mpv") === "native"
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
