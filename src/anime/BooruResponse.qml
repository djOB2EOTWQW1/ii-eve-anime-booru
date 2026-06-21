import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarPolicies
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    property var responseData
    property var tagInputField

    property string previewDownloadPath
    property string downloadPath
    property string nsfwPath

    property real availableWidth: parent.width
    property real rowTooShortThreshold: ExtensionManager.getExtensionConfig("ii-eve-anime-booru", "rowTooShortThreshold", Config.options?.sidebar?.booru?.rowTooShortThreshold ?? 250)
    property real imageSpacing: 5
    property real responsePadding: 5

    // Previews that need a curl fetch (Referer/UA) instead of a direct Image load.
    readonly property var manualDownloadProviders: ["danbooru", "waifu.im", "t.alcy.cc", "konachan", "gelbooru"]
    readonly property bool manualDownload: manualDownloadProviders.includes(root.responseData.provider)
    // Gelbooru hotlink protection: any gelbooru.com referer works (no need for the post id).
    readonly property string previewReferer: root.responseData.provider === "gelbooru" ? "https://gelbooru.com/" : ""
    readonly property string previewQuality: ExtensionManager.getExtensionConfig("ii-eve-anime-booru", "previewQuality", Config.options?.sidebar?.booru?.previewQuality ?? "preview")
    property bool previewsReady: !root.manualDownload

    function _previewExt(img) {
        const e = (img.file_ext ?? "").toLowerCase().replace(/^\./, "");
        if (e) return e;
        const u = (img.file_url ?? "").split("?")[0];
        return u.substring(u.lastIndexOf(".") + 1).toLowerCase();
    }
    // Mirror of BooruImage's quality resolution so prefetch paths match what it displays.
    function _resolvePreview(img) {
        const isStaticVideo = ["mp4", "webm", "m4v", "mov"].includes(root._previewExt(img));
        let url;
        if (isStaticVideo) url = img.preview_url ?? img.sample_url ?? img.file_url;
        else if (root.previewQuality === "full") url = img.file_url ?? img.sample_url ?? img.preview_url;
        else if (root.previewQuality === "sample") url = img.sample_url ?? img.file_url ?? img.preview_url;
        else url = img.preview_url ?? img.sample_url ?? img.file_url;
        const clean = (url ?? "").split("?")[0];
        const name = decodeURIComponent(clean.substring(clean.lastIndexOf("/") + 1));
        return { "url": url, "path": `${root.previewDownloadPath}/${name}` };
    }
    function _buildEntries() {
        if (!root.manualDownload) return [];
        return (root.responseData.images || []).map(img => root._resolvePreview(img)).filter(e => e.url);
    }
    function startPrefetch() {
        if (!root.manualDownload) return;
        root.previewsReady = false;
        prefetch.running = false;
        Qt.callLater(() => prefetch.running = true);
    }

    Component.onCompleted: root.startPrefetch()
    onPreviewQualityChanged: root.startPrefetch()

    BooruPagePrefetch {
        id: prefetch
        entries: root._buildEntries()
        dir: root.previewDownloadPath
        referer: root.previewReferer
        onFinished: root.previewsReady = true
    }

    readonly property var providerIcons: ({
        "yandere": "image", "konachan": "wallpaper", "zerochan": "child_care",
        "danbooru": "photo_library", "gelbooru": "collections",
        "waifu.im": "favorite", "t.alcy.cc": "landscape", "system": "info"
    })

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: columnLayout.implicitHeight + root.responsePadding * 2

    Component.onCompleted: {
        // Break property bind to prevent aggressive updates
        availableWidth = parent.width
    }

    Connections {
        target: parent
        function onWidthChanged() {
            updateWidthTimer.restart()
        }
    }

    Timer {
        id: updateWidthTimer
        interval: 100
        onTriggered: {
            availableWidth = parent.width
        }
    }

    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1

    ColumnLayout {
        id: columnLayout
        
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: responsePadding
        spacing: root.imageSpacing

        RowLayout { // Header
            spacing: 9

            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: Appearance.rounding.small
                color: Appearance.colors.colPrimaryContainer
                Layout.alignment: Qt.AlignVCenter

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.providerIcons[root.responseData.provider] ?? "image_search"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    text: Booru.providers[root.responseData.provider].name
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    visible: root.responseData.images.length > 0
                    text: Translation.tr("%1 results").arg(root.responseData.images.length)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle { // Page pill
                visible: root.responseData.page != "" && root.responseData.page > 0
                radius: Appearance.rounding.full
                color: Appearance.colors.colSurfaceContainerHighest
                implicitHeight: pageNumber.implicitHeight + 8
                implicitWidth: pageNumber.implicitWidth + 24
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    id: pageNumber
                    anchors.centerIn: parent
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer2
                    text: Translation.tr("Page %1").arg(root.responseData.page)
                }
            }
        }

        StyledFlickable { // Tag strip
            id: tagsFlickable
            visible: root.responseData.tags.length > 0
            Layout.alignment: Qt.AlignLeft
            Layout.fillWidth: true
            implicitHeight: tagRowLayout.implicitHeight
            contentWidth: tagRowLayout.implicitWidth

            clip: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: tagsFlickable.width
                    height: tagsFlickable.height
                    radius: Appearance.rounding.small
                }
            }

            Behavior on implicitHeight {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }

            RowLayout {
                id: tagRowLayout
                Layout.alignment: Qt.AlignBottom

                Repeater {
                    id: tagRepeater
                    model: root.responseData.tags

                    ApiCommandButton {
                        Layout.fillWidth: false
                        buttonText: modelData
                        colBackground: Appearance.colors.colSecondaryContainer
                        onClicked: {
                            if(root.tagInputField.text.length !== 0) root.tagInputField.text += " "
                            root.tagInputField.text += modelData
                        }
                    }
                }
                
            }
        }

        StyledText { // Message
            id: messageText
            Layout.fillWidth: true
            visible: root.responseData.message.length > 0
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: root.responseData.message
            wrapMode: Text.WordWrap
            Layout.margins: responsePadding
            textFormat: Text.MarkdownText
            onLinkActivated: (link) => {
                Qt.openUrlExternally(link)
                GlobalStates.sidebarLeftOpen = false
            }
            PointingHandLinkHover {}
        }

        Repeater {
            model: ScriptModel {
                values: {
                    // Greedily add images to a row as long as rowHeight >= rowTooShortThreshold
                    let i = 0;
                    let rows = [];
                    const responseList = root.responseData.images;
                    const minRowHeight = rowTooShortThreshold;
                    const availableImageWidth = availableWidth - root.imageSpacing - (responsePadding * 2);

                    while (i < responseList.length) {
                        let row = {
                            height: 0,
                            images: [],
                        };
                        let j = i;
                        let combinedAspect = 0;
                        let rowHeight = 0;

                        // Try to add as many images as possible without going below minRowHeight
                        while (j < responseList.length) {
                            combinedAspect += responseList[j].aspect_ratio;
                            // Subtract imageSpacing for each gap between images in the row
                            let imagesInRow = j - i + 1;
                            let totalSpacing = root.imageSpacing * (imagesInRow - 1);
                            let rowAvailableWidth = availableImageWidth - totalSpacing;
                            rowHeight = rowAvailableWidth / combinedAspect;
                            if (rowHeight < minRowHeight) {
                                combinedAspect -= responseList[j].aspect_ratio;
                                imagesInRow -= 1;
                                totalSpacing = root.imageSpacing * (imagesInRow - 1);
                                rowAvailableWidth = availableImageWidth - totalSpacing;
                                rowHeight = rowAvailableWidth / combinedAspect;
                                break;
                            }
                            j++;
                        }

                        // If we couldn't add any image (shouldn't happen), add at least one
                        if (j === i) {
                            row.images.push(responseList[i]);
                            row.height = availableImageWidth / responseList[i].aspect_ratio;
                            rows.push(row);
                            i++;
                        } else {
                            for (let k = i; k < j; k++) {
                                row.images.push(responseList[k]);
                            }
                            // Recalculate spacing for the final row
                            let imagesInRow = j - i;
                            let totalSpacing = root.imageSpacing * (imagesInRow - 1);
                            let rowAvailableWidth = availableImageWidth - totalSpacing;
                            row.height = rowAvailableWidth / combinedAspect;
                            rows.push(row);
                            i = j;
                        }
                    }
                    return rows;
                }
            }
            delegate: RowLayout {
                id: imageRow
                required property var modelData
                property var rowHeight: modelData.height
                spacing: root.imageSpacing

                Repeater {
                    model: modelData.images
                    delegate: BooruImage {
                        required property var modelData
                        imageData: modelData
                        rowHeight: imageRow.rowHeight
                        imageRadius: imageRow.modelData.images.length == 1 ? 50 : Appearance.rounding.normal
                        // Previews are prefetched at the page level (one curl), not per image.
                        manualDownload: root.manualDownload
                        previewsReady: root.previewsReady
                        previewDownloadPath: root.previewDownloadPath
                        downloadPath: root.downloadPath
                        nsfwPath: root.nsfwPath
                        tagInputField: root.tagInputField
                    }
                }
            }
        }

    }
}
