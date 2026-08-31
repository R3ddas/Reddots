import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland


ColumnLayout {
    id: root
    spacing: 6

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property var active: adapter
    ? adapter.devices.values.find(d => d.connected) ?? null
    : null

    readonly property string icon: {
        if (!powered) return String.fromCodePoint(0xF00B2)  // bluetooth-off
            if (!active)  return String.fromCodePoint(0xF00AF)  // bluetooth
                return String.fromCodePoint(0xF00B1)                // bluetooth-connect
    }

    Text {
        id: iconText
        text: root.icon
        font.pixelSize: 18
        color: root.powered ? Theme.text : Theme.textMuted

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: event => {
                if (event.button === Qt.RightButton) {
                    menu.visible = !menu.visible
                } else if (root.adapter) {
                    root.adapter.enabled = !root.adapter.enabled
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
            if (visible) grabTimer.restart()
                else { grabTimer.stop(); grab.active = false }
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
                    visible: (root.adapter?.devices.values.length ?? 0) === 0
                    text: root.powered ? "Sin dispositivos" : "Bluetooth apagado"
                    color: Theme.textDisabled
                }

                Repeater {
                    model: root.adapter?.devices ?? null

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 26
                        radius: 4
                        color: deviceMouse.containsMouse ? Theme.surfaceHover : "transparent"

                        Text {
                            id: deviceLabel
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 12
                            text: (modelData.connected ? "󰂱  " : "󰂯  ") + modelData.name
                            color: modelData.connected ? Theme.text : Theme.textDisabled
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: deviceMouse
                            x: 0
                            y: 0
                            width: parent.width
                            height: parent.height
                            hoverEnabled: true
                            onClicked: {
                                if (modelData.connected) modelData.disconnect()
                                    else modelData.connect()
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
}
