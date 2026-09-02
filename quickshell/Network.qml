// Recursos: https://www.youtube.com/watch?v=Vlpyz4c4Xdw

import Quickshell
import Quickshell.Networking  // Para la información de las conexiones
import Quickshell.Hyprland    // Para el HyprlandFocusGrab
import QtQuick
import QtQuick.Layouts          // Para usar RowLayout o ColumnLayout

ColumnLayout{
    id: root
    spacing: 6

    property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    property var active: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) : null

    readonly property real signal: active? active.signalStrength : 0

    readonly property string icon: {
        if (!Networking.wifiEnabled) return String.fromCodePoint (0xF05AA)
        if (!active) return String.fromCodePoint(0xF092D)

        let tier = signal >= 0.75 ? 3
                 : signal >= 0.50 ? 2
                 : signal >= 0.25 ? 1
                 : 0
        return String.fromCodePoint(0xF091F + tier*3)
    }

    function tryConnect(network, psk) {          // Conecta con contraseña y cierra el campo de texto
        network.connectWithPsk(psk)
        menu.expandedNetwork = null
    }

    Text{
        id: iconText
        text: root.icon
        color: Networking.wifiEnabled? Theme.textActive : Theme.textDisabled
        font.pixelSize: 18

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: event => {
                if (event.button === Qt.RightButton) {
                    Networking.wifiEnabled = !Networking.wifiEnabled
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

        property var expandedNetwork: null      // Red a la espera de que se introduzca la contraseña

        anchor.item: iconText
        anchor.rect.y: iconText.height + 8
        anchor.gravity: Edges.Bottom

        implicitWidth: 260
        implicitHeight: Math.max(40, listCol.implicitHeight + 16)

        onVisibleChanged: {
            if (visible) {
                grabTimer.restart()
                if (root.wifiDevice) root.wifiDevice.scannerEnabled = true    // Fuerza un escaneo al abrir la lista
            } else {
                grabTimer.stop()
                grab.active = false
                if (root.wifiDevice) root.wifiDevice.scannerEnabled = false   // Deja de escanear al cerrar (ahorra batería)
                expandedNetwork = null
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
                    visible: !Networking.wifiEnabled
                    text: "Wifi apagado"
                    color: Theme.textDisabled
                }

                Text {
                    Layout.fillWidth: true
                    visible: Networking.wifiEnabled && (!root.wifiDevice || root.wifiDevice.networks.values.length === 0)
                    text: root.wifiDevice ? "Buscando redes..." : "Sin adaptador wifi"
                    color: Theme.textDisabled
                }

                Repeater {
                    model: Networking.wifiEnabled ? (root.wifiDevice ? root.wifiDevice.networks : null) : null

                    delegate: ColumnLayout {
                        id: delegateRoot
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 2

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 26
                            radius: 4
                            color: netMouse.containsMouse ? Theme.surfaceHover : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: (modelData.connected ? "✓ " : "") + modelData.name
                                    color: modelData.connected ? Theme.textSelected : Theme.textActive
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: modelData.security !== WifiSecurityType.Open
                                    text: "🔒"
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                id: netMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (modelData.connected) {
                                        modelData.disconnect()
                                    } else if (modelData.known || modelData.security === WifiSecurityType.Open) {
                                        modelData.connect()
                                    } else {
                                        menu.expandedNetwork = (menu.expandedNetwork === modelData) ? null : modelData
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: menu.expandedNetwork === modelData
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 22
                                radius: 4
                                color: Theme.background
                                border.color: Theme.border

                                TextInput {
                                    id: pskInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.textActive
                                    echoMode: TextInput.Password
                                    focus: menu.expandedNetwork === modelData
                                    onAccepted: root.tryConnect(modelData, text)
                                }
                            }

                            Text {
                                text: "Conectar"
                                color: Theme.textActive

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onClicked: root.tryConnect(modelData, pskInput.text)
                                }
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
