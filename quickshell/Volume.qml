import Quickshell
import Quickshell.Services.Pipewire   // Para el control de volumen (Pipewire)
import Quickshell.Hyprland            // Para el HyprlandFocusGrab
import QtQuick
import QtQuick.Layouts                // Para usar RowLayout o ColumnLayout

ColumnLayout{
    id: root
    spacing: 6

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink ? sink.audio.muted : true
    readonly property real volume: sink ? sink.audio.volume : 0

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)

    function setVolume(fraction) {
        if (!root.sink) return
        const v = Math.max(0, Math.min(1, fraction))
        root.sink.audio.volume = v
        if (v > 0) root.sink.audio.muted = false
    }

    readonly property string icon: {
        if (!sink || muted) return String.fromCodePoint(0xF075F)  // volume-mute
        if (volume >= 0.66) return String.fromCodePoint(0xF057E)  // volume-high
        if (volume > 0)     return String.fromCodePoint(0xF0580)  // volume-medium
        return String.fromCodePoint(0xF057F)                      // volume-low
    }

    Text{
        id: iconText
        text: root.icon
        color: root.muted ? Theme.textDisabled : Theme.textActive
        font.pixelSize: 18

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: event => {
                if (event.button === Qt.RightButton) {
                    if (root.sink) root.sink.audio.muted = !root.sink.audio.muted
                } else {
                    menu.visible = !menu.visible
                }
            }
        }
    }

    PopupWindow {
        id: menu
        visible: false
        color: "transparent"

        anchor.item: iconText
        anchor.rect.y: iconText.height + 8
        anchor.gravity: Edges.Bottom

        implicitWidth: 240
        implicitHeight: Math.max(40, listCol.implicitHeight + 16)

        onVisibleChanged: {
            if (visible) {
                grabTimer.restart()
            } else {
                grabTimer.stop()
                grab.active = false
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.surface
            radius: 8
            border.color: Theme.border

            ColumnLayout {
                id: listCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        id: sliderTrack
                        Layout.fillWidth: true
                        implicitHeight: 14
                        radius: 7
                        color: Theme.background
                        border.color: Theme.border

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * Math.min(root.volume, 1)
                            radius: parent.radius
                            color: root.muted ? Theme.textDisabled : Theme.textSelected
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: mouse => root.setVolume(mouse.x / width)
                            onPositionChanged: mouse => { if (pressed) root.setVolume(mouse.x / width) }
                            onWheel: wheel => root.setVolume(root.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                        }
                    }

                    Text {
                        text: Math.round(Math.min(root.volume, 1) * 100) + "%"
                        color: Theme.textActive
                        font.pixelSize: 11
                        Layout.preferredWidth: 32
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.border
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.sinks.length === 0
                    text: "Sin salidas de audio"
                    color: Theme.textDisabled
                }

                Repeater {
                    model: root.sinks

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 26
                        radius: 4
                        color: outMouse.containsMouse ? Theme.surfaceHover : "transparent"

                        Text {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 12
                            text: (modelData === root.sink ? "✓ " : "") + (modelData.nickname || modelData.description || modelData.name)
                            color: modelData === root.sink ? Theme.textSelected : Theme.textActive
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: outMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Pipewire.preferredDefaultAudioSink = modelData
                                menu.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [menu]
        active: false
        onCleared: menu.visible = false
    }

    Timer {
        id: grabTimer
        interval: 5
        onTriggered: grab.active = true
    }

    PwObjectTracker {
        objects: root.sinks
    }
}
