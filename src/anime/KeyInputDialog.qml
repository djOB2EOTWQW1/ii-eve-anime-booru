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
    backgroundWidth: 380
    show: false

    required property string keyType

    signal closed()

    Component.onCompleted: {
        show = true
        dialogInput.forceActiveFocus()
    }

    onDismiss: {
        show = false
    }

    onVisibleChanged: {
        if (!visible) {
            root.closed()
        }
    }

    MaterialSymbol {
        Layout.alignment: Qt.AlignHCenter
        iconSize: 26
        text: root.keyType === "gelbooru_id" ? "person" :
        root.keyType === "gelbooru_pass_hash" ? "password" :
        root.keyType === "danbooru_login" ? "person" : "key"
        color: Appearance.colors.colSecondary
    }

    StyledText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Appearance.font.pixelSize.large
        font.weight: Font.DemiBold
        color: Appearance.m3colors.m3onSurface
        text: {
            if (root.keyType === "gelbooru_key")
                return Translation.tr("Gelbooru API Key")
                if (root.keyType === "gelbooru_id")
                    return Translation.tr("Gelbooru User ID")
                    if (root.keyType === "gelbooru_pass_hash")
                        return Translation.tr("Gelbooru Pass Hash")
                        if (root.keyType === "danbooru_key")
                            return Translation.tr("Danbooru API Key")
                            if (root.keyType === "danbooru_login")
                                return Translation.tr("Danbooru Login")
                                return ""
        }
    }

    MaterialTextField {
        id: dialogInput
        Layout.fillWidth: true
        focus: true
        placeholderText: {
            if (root.keyType === "gelbooru_key")
                return Translation.tr("Enter API Key...")
                if (root.keyType === "gelbooru_id")
                    return Translation.tr("Enter User ID...")
                    if (root.keyType === "gelbooru_pass_hash")
                        return Translation.tr("Enter Pass Hash...")
                        if (root.keyType === "danbooru_key")
                            return Translation.tr("Enter API Key...")
                            if (root.keyType === "danbooru_login")
                                return Translation.tr("Enter Login...")
                                return ""
        }

        Keys.onPressed: event => {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
                event.accepted = false
            } else if (event.key === Qt.Key_Escape) {
                root.dismiss()
                event.accepted = true
            }
        }

        onAccepted: root.submitValue()
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 10
        Item { Layout.fillWidth: true }

        DialogButton {
            buttonText: Translation.tr("Cancel")
            onClicked: root.dismiss()
        }

        DialogButton {
            enabled: dialogInput.text.trim().length > 0
            buttonText: Translation.tr("Save")
            onClicked: root.submitValue()
        }
    }

    function submitValue() {
        const value = dialogInput.text.trim()
        if (value.length === 0) return

            if (root.keyType === "gelbooru_key") {
                KeyringStorage.setNestedField(["apiKeys", "gelbooru"], value)
            } else if (root.keyType === "gelbooru_id") {
                KeyringStorage.setNestedField(["apiKeys", "gelbooru_user_id"], value)
            } else if (root.keyType === "gelbooru_pass_hash") {
                KeyringStorage.setNestedField(["apiKeys", "gelbooru_pass_hash"], value)
            } else if (root.keyType === "danbooru_key") {
                KeyringStorage.setNestedField(["apiKeys", "danbooru"], value)
            } else if (root.keyType === "danbooru_login") {
                KeyringStorage.setNestedField(["apiKeys", "danbooru_user_id"], value)
            }

            root.dismiss()
    }
}
