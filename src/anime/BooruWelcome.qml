import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.animations
import qs.modules.common.functions
import qs.modules.ii.sidebarPolicies
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property var tagInputField

    // Opening animation (mirrors PlaceholderOpeningAnimation, adapted to the hero shape)
    property bool triggerAnimationOn: false
    property bool rotateToRight: true

    onTriggerAnimationOnChanged: {
        if (!triggerAnimationOn) return;
        heroRotationAnim.from = rotateToRight ? -50 : 50;
        openingAnimation.restart();
    }

    SequentialAnimation {
        id: openingAnimation
        ParallelAnimation {
            PropertyAnimation {
                id: heroRotationAnim
                target: heroShape
                property: "rotation"
                to: 0
                duration: 250
                easing.type: Easing.OutCubic
            }
            BounceAnimation {
                target: heroShape
                propertyName: "scale"
                peak: 1.1
                totalDuration: 400
            }
        }
    }

    readonly property var recent: Persistent.states.booru.searchHistory ?? []

    ColumnLayout {
        anchors {
            fill: parent
            margins: 4
        }
        spacing: 12

        ProviderChipStrip { // Provider switcher
            Layout.fillWidth: true
        }

        Rectangle { // Hero banner
            Layout.fillWidth: true
            implicitHeight: 150
            radius: Appearance.rounding.normal
            color: Appearance.colors.colPrimaryContainer

            MaterialShape {
                id: heroShape
                shapeString: "Cookie9Sided"
                implicitSize: 96
                color: Appearance.colors.colPrimary
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    margins: 20
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "bookmark_heart"
                    iconSize: 44
                    color: Appearance.colors.colOnPrimary
                }
            }

            Rectangle { // Provider pill
                anchors {
                    right: parent.right
                    top: parent.top
                    margins: 16
                }
                radius: Appearance.rounding.full
                color: Appearance.colors.colOnPrimary
                implicitHeight: pillRow.implicitHeight + 10
                implicitWidth: pillRow.implicitWidth + 20

                RowLayout {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialSymbol {
                        text: "api"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        text: Booru.providers[Booru.currentProvider]?.name ?? Booru.currentProvider
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
            }

            StyledText { // Title
                text: Translation.tr("Anime boorus")
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: 6
                    margins: 20
                }
                horizontalAlignment: Text.AlignRight
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.hugeass
                    weight: Font.Black
                }
                color: Appearance.colors.colOnPrimaryContainer
            }

            StyledText { // Subtitle
                text: Translation.tr("Search any tag")
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    margins: 20
                }
                horizontalAlignment: Text.AlignRight
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.large
                    weight: Font.Black
                }
                opacity: 0.85
                color: Appearance.colors.colOnPrimaryContainer
            }
        }

        StyledText { // Popular label
            text: Translation.tr("Popular")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            Layout.leftMargin: 4
        }

        FlowButtonGroup { // Popular tags
            Layout.fillWidth: true
            spacing: 7
            Repeater {
                model: Config.options?.sidebar?.booru?.popularTags ?? ["scenery", "1girl", "landscape", "cat", "wallpaper"]
                delegate: ApiCommandButton {
                    required property var modelData
                    buttonText: modelData
                    colBackground: Appearance.colors.colSecondaryContainer
                    onClicked: {
                        // Searching populates responses -> welcomeLoader.active=false ->
                        // this delegate (and root) get destroyed. Capture the Anime-owned
                        // input field (which survives) and defer; never touch root after.
                        const field = root.tagInputField
                        const tag = modelData
                        Qt.callLater(() => {
                            field.text = tag
                            field.accept()
                        })
                    }
                }
            }
        }

        StyledText { // Recent label
            text: Translation.tr("Recent")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            Layout.leftMargin: 4
        }

        Item { // Recent container — always fills remaining height so layout stays put
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout { // Empty placeholder
                visible: root.recent.length === 0
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "history"
                    iconSize: 40
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No recent searches")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }

            StyledListView { // Recent searches (inline)
            anchors.fill: parent
            visible: root.recent.length > 0
            clip: true
            spacing: 6

            model: ScriptModel {
                values: root.recent
            }

            delegate: RippleButton {
                required property var modelData
                anchors.left: parent?.left
                anchors.right: parent?.right
                implicitHeight: recentRow.implicitHeight + 18
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover

                onClicked: {
                    const entry = modelData
                    const searchText = entry.tags.join(" ") + (entry.page > 1 ? " " + entry.page : "")
                    const targetProvider = (entry.provider && entry.provider !== Booru.currentProvider) ? entry.provider : ""
                    // Searching/changing provider populates responses -> welcome (and root)
                    // get destroyed. Capture the Anime-owned field (survives), set the
                    // provider directly via Persistent (no system message), then defer the
                    // search through the field. Never touch root after this point.
                    const field = root.tagInputField
                    Qt.callLater(() => {
                        if (targetProvider) Persistent.states.booru.provider = targetProvider
                        field.text = searchText
                        field.accept()
                    })
                }

                contentItem: RowLayout {
                    id: recentRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        margins: 11
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 9
                    MaterialSymbol {
                        text: "undo"
                        iconSize: 16
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.tags?.join(", ") || Translation.tr("[no tags]")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    StyledText {
                        text: Translation.tr("p%1 · %2")
                            .arg(modelData.page ?? 1)
                            .arg(Booru.providers[modelData.provider]?.name ?? modelData.provider ?? "?")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }
            }
        }
    }
}
