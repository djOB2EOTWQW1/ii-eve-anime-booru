import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundWidth: 420
    show: false

    signal closed()

    Component.onCompleted: show = true

    onDismiss: show = false
    onVisibleChanged: {
        if (!visible) root.closed()
    }

    MaterialSymbol {
        Layout.alignment: Qt.AlignHCenter
        iconSize: 26
        text: "key"
        color: Appearance.colors.colSecondary
    }

    StyledText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Appearance.font.pixelSize.large
        font.weight: Font.DemiBold
        color: Appearance.m3colors.m3onSurface
        text: Translation.tr("How to set up API keys")
    }

    ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: 400
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        StyledText {
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.MarkdownText
            color: Appearance.m3colors.m3onSurface
            font.pixelSize: Appearance.font.pixelSize.small
            text: {
                if (Booru.currentProvider === "gelbooru") {
                    return "# Gelbooru\n\n" +
                    "1. Register on [Gelbooru](https://gelbooru.com/index.php?page=account&s=home)\n" +
                    "2. After registration, go to [Options](https://gelbooru.com/index.php?page=account&s=options)\n" +
                    "3. Copy the `api_key` and `user_id` values (after =)\n" +
                    "- paste them into the corresponding fields.\n" +
                    "4. If you want to unlock the **'Add to favorites'** button\n" +
                    "- open developer settings in the browser\n" +
                    "- go to **Storage → Cookies**\n" +
                    "- copy the `pass_hash` value\n" +
                    "- paste them into the corresponding fields.\n" +
                    "### WITHOUT AN API KEY IT DOESN'T WORK"
                } else if (Booru.currentProvider === "danbooru") {
                    return "## Danbooru\n\n" +
                    "1. Register on [Danbooru](https://danbooru.donmai.us/)\n" +
                    "2. After registration, go to [API Keys settings](https://danbooru.donmai.us/users/1470906/api_keys)\n" +
                    "3. Create a new API key\n" +
                    "- Copy the `api_key` and `login` values (after =)\n" +
                    "4. paste them into the corresponding fields.\n" +
                    "#### This can work without the API, but with some limits."
                } else if (Booru.currentProvider === "zerochan") {
                    return "## Zerochan\n\n" +
                    "1. WORK IN PROGRESS\n" +
                    "### WITHOUT AN API KEY IT DOESN'T WORK"
                }
                return "";
            }
            onLinkActivated: (link) => Qt.openUrlExternally(link)
            PointingHandLinkHover {}
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 10
        Item { Layout.fillWidth: true }
        DialogButton {
            buttonText: Translation.tr("Close")
            onClicked: root.dismiss()
        }
    }
}
