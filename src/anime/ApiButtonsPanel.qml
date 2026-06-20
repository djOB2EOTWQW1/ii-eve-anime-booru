import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    required property var responses

    implicitWidth: contentLayout.implicitWidth
    implicitHeight: contentLayout.implicitHeight
    anchors.horizontalCenter: parent.horizontalCenter

    signal openKeyInputDialog(string keyType)

    ColumnLayout {
        id: contentLayout
        width: 330
        anchors.horizontalCenter: parent.horizontalCenter

        RowLayout {
            id: providerSelector
            Layout.alignment: Qt.AlignHCenter
            width: parent.width
            spacing: 2

            property var options: {
                var opts = []
                if (Booru.currentProvider === "gelbooru") {
                    if (!Booru.apiKeys["gelbooru"])
                        opts.push({ displayName: "API Key", icon: "key", value: "gelbooru_key" })
                        if (!Booru.apiKeys["gelbooru_user_id"])
                            opts.push({ displayName: "User ID", icon: "person", value: "gelbooru_id" })
                            if (!Booru.apiKeys["gelbooru_pass_hash"])
                                opts.push({ displayName: "Pass Hash", icon: "password", value: "gelbooru_pass_hash" })
                }
                else if (Booru.currentProvider === "danbooru") {
                    if (!Booru.apiKeys["danbooru"])
                        opts.push({ displayName: "API Key", icon: "key", value: "danbooru_key" })
                        if (!Booru.apiKeys["danbooru_user_id"])
                            opts.push({ displayName: "Login", icon: "person", value: "danbooru_login" })
                }
                return opts
            }

            Repeater {
                model: providerSelector.options
                delegate: SelectionGroupButton {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    leftmost: index === 0
                    rightmost: index === providerSelector.options.length - 1
                    toggled: false

                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colBackgroundActive: Appearance.colors.colSecondaryContainerActive

                    onClicked: root.openKeyInputDialog(modelData.value)

                    contentItem: Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Item {
                            width: Appearance.font.pixelSize.larger
                            height: Appearance.font.pixelSize.larger
                            anchors.verticalCenter: parent.verticalCenter

                            MaterialSymbol {
                                anchors.centerIn: parent
                                width: Appearance.font.pixelSize.larger
                                height: Appearance.font.pixelSize.larger
                                text: modelData.icon
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.displayName
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }
            }
        }
    }
}
