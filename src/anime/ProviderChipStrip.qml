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
    implicitHeight: 66

    readonly property var providers: [
        { title: "yande.re", icon: "image", value: "yandere" },
        { title: "Konachan", icon: "wallpaper", value: "konachan" },
        { title: "Zerochan", icon: "child_care", value: "zerochan" },
        { title: "Danbooru", icon: "photo_library", value: "danbooru" },
        { title: "Gelbooru", icon: "collections", value: "gelbooru" },
        { title: "waifu.im", icon: "favorite", value: "waifu.im" },
        { title: "Alcy", icon: "landscape", value: "t.alcy.cc" }
    ]

    ScrollEdgeFade {
        z: 1
        target: stripView
        vertical: false
    }

    StyledListView {
        id: stripView
        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: 7
        clip: true

        model: ScriptModel {
            values: root.providers
        }

        delegate: RippleButton {
            id: chip
            required property var modelData
            property bool active: modelData.value === Booru.currentProvider
            implicitWidth: 64
            implicitHeight: 64
            buttonRadius: Appearance.rounding.normal
            colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
            colBackgroundHover: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1Hover

            onClicked: {
                Persistent.states.booru.provider = chip.modelData.value
            }

            contentItem: ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: Appearance.rounding.small
                    color: chip.active ? Appearance.colors.colPrimary : Appearance.colors.colLayer2

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: chip.modelData.icon
                        iconSize: Appearance.font.pixelSize.large
                        color: chip.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: chip.modelData.title
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: chip.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    Layout.maximumWidth: 60
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
