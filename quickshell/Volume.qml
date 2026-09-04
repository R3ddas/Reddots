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
                            text: (modelData === root.sink ? "✓ " : "") + (modelData.description || modelData.name)
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
