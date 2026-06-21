import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    property string source: ""
    property real cornerRadius: Appearance.rounding.small
    signal closeRequested()

    property bool fullscreen: false
    property bool controlsShown: hoverHandler.hovered || mediaPlayer.playbackState !== MediaPlayer.PlayingState
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)

    function formatTime(ms) {
        if (!ms || ms < 0) return "0:00"
        const total = Math.floor(ms / 1000)
        const m = Math.floor(total / 60)
        const s = total % 60
        return `${m}:${s.toString().padStart(2, '0')}`
    }

    MediaPlayer {
        id: mediaPlayer
        source: root.source
        videoOutput: inlineVideo
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput {
            id: audioOutput
            volume: 1.0
        }
        Component.onCompleted: play()
    }

    Rectangle { // Background (sibling behind VideoOutput: a rounded clip breaks video rendering)
        anchors.fill: parent
        radius: root.cornerRadius
        color: "black"
    }

    VideoOutput {
        id: inlineVideo
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
        visible: !root.fullscreen
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: mediaPlayer.mediaStatus === MediaPlayer.LoadingMedia
            || mediaPlayer.mediaStatus === MediaPlayer.StalledMedia
        visible: running && !root.fullscreen
    }

    HoverHandler {
        id: hoverHandler
    }

    TapHandler {
        onTapped: mediaPlayer.playbackState === MediaPlayer.PlayingState ? mediaPlayer.pause() : mediaPlayer.play()
    }

    component CtrlButton: RippleButton {
        property string symbolName
        implicitWidth: 30
        implicitHeight: 30
        padding: 0
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: ColorUtils.transparentize("#ffffff", 0.8)
        colRipple: ColorUtils.transparentize("#ffffff", 0.7)
        contentItem: MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: parent.symbolName
            iconSize: Appearance.font.pixelSize.larger
            color: "white"
        }
    }

    component Controls: Item {
        id: controlsRoot
        property bool isFullscreen: false
        implicitHeight: controlsColumn.implicitHeight

        Rectangle { // Scrim
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: ColorUtils.transparentize("#000000", 0.2) }
            }
        }

        ColumnLayout {
            id: controlsColumn
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 12
                rightMargin: 12
                bottomMargin: 8
            }
            spacing: 2

            StyledSlider { // Seek
                id: seekSlider
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, mediaPlayer.duration)
                usePercentTooltip: false
                tooltipContent: root.formatTime(value)
                onPressedChanged: if (!pressed) mediaPlayer.setPosition(value)

                Connections {
                    target: mediaPlayer
                    function onPositionChanged() {
                        if (!seekSlider.pressed) seekSlider.value = mediaPlayer.position
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                CtrlButton {
                    symbolName: mediaPlayer.playbackState === MediaPlayer.PlayingState ? "pause" : "play_arrow"
                    onClicked: mediaPlayer.playbackState === MediaPlayer.PlayingState ? mediaPlayer.pause() : mediaPlayer.play()
                }

                StyledText {
                    text: `${root.formatTime(mediaPlayer.position)} / ${root.formatTime(mediaPlayer.duration)}`
                    color: "white"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                Item { Layout.fillWidth: true }

                CtrlButton {
                    symbolName: audioOutput.muted || audioOutput.volume <= 0 ? "volume_off" : "volume_up"
                    onClicked: audioOutput.muted = !audioOutput.muted
                }

                StyledSlider {
                    Layout.preferredWidth: controlsRoot.isFullscreen ? 120 : 70
                    from: 0
                    to: 1
                    value: audioOutput.volume
                    usePercentTooltip: true
                    onMoved: {
                        audioOutput.volume = value
                        audioOutput.muted = false
                    }
                }

                CtrlButton {
                    symbolName: root.fullscreen ? "fullscreen_exit" : "fullscreen"
                    onClicked: root.fullscreen = !root.fullscreen
                }

                CtrlButton {
                    symbolName: "close"
                    onClicked: root.closeRequested()
                }
            }
        }
    }

    Controls { // Inline controls
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        visible: !root.fullscreen && root.controlsShown
        opacity: visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
    }

    Loader { // Fullscreen window
        active: root.fullscreen
        sourceComponent: PanelWindow {
            id: fsWindow
            visible: true
            color: "black"
            screen: root.focusedScreen

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:booruVideo"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            implicitWidth: root.focusedScreen?.width ?? 0
            implicitHeight: root.focusedScreen?.height ?? 0

            Component.onCompleted: mediaPlayer.videoOutput = fsVideo
            Component.onDestruction: mediaPlayer.videoOutput = inlineVideo

            VideoOutput {
                id: fsVideo
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
            }

            HoverHandler {
                id: fsHover
            }

            TapHandler {
                onTapped: mediaPlayer.playbackState === MediaPlayer.PlayingState ? mediaPlayer.pause() : mediaPlayer.play()
            }

            Controls {
                isFullscreen: true
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                visible: fsHover.hovered || mediaPlayer.playbackState !== MediaPlayer.PlayingState
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.fullscreen = false
            }
        }
    }
}
