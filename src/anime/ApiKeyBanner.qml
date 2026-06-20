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

    implicitWidth: bannerLayout.implicitWidth
    implicitHeight: bannerLayout.implicitHeight
    anchors.horizontalCenter: parent.horizontalCenter

    signal learnMoreClicked()

    ColumnLayout {
        id: bannerLayout
        width: 330
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            radius: Appearance.rounding.normal
            color: Appearance.colors.colSecondaryContainer
            implicitHeight: bannerContent.implicitHeight + 20

            ColumnLayout {
                id: bannerContent
                anchors { fill: parent; margins: 10 }
                spacing: 6

                RowLayout {
                    MaterialSymbol {
                        text: "info"
                        iconSize: 20
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("API keys improve search results")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSecondaryContainer
                        wrapMode: Text.Wrap
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    DialogButton {
                        buttonText: Translation.tr("Learn more")
                        onClicked: root.learnMoreClicked()
                    }

                    Item { Layout.fillWidth: true }

                    DialogButton {
                        buttonText: Translation.tr("Don't show again")
                        onClicked: {
                            if ("apiKeyBannerDismissed" in Persistent.states.booru)
                                Persistent.states.booru.apiKeyBannerDismissed = true
                        }
                    }
                }
            }
        }
    }
}
