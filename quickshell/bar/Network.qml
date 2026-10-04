// Icono de red en la barra: cable, o wifi con la intensidad de la señal.
//   Clic izquierdo: menú con las redes wifi (busca mientras está abierto). Pulsar una red
//   conecta (o desconecta la actual); las que piden contraseña o usuario abren el campo
//   para escribirlos
//   Clic derecho: enciende/apaga el wifi
// Las conexiones las lleva services/NetworkMonitor.qml; aquí solo se pinta.
// Recursos: https://www.youtube.com/watch?v=Vlpyz4c4Xdw
// https://www.nerdfonts.com/

import Quickshell
import Quickshell.Networking  // Para la información de las conexiones
import QtQuick
import QtQuick.Layouts          // Para usar RowLayout o ColumnLayout
import qs.components
import qs.services

ColumnLayout{
    id: root
    spacing: 6

    property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired)
    property var active: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) : null

    readonly property bool wiredConnected: wiredDevice ? wiredDevice.connected : false
    readonly property real signal: active? active.signalStrength : 0

    readonly property string icon: {
        if (wiredConnected) return String.fromCodePoint(0xf0317)  // ethernet
        if (!Networking.wifiEnabled) return String.fromCodePoint (0xF05AA)
        if (!active) return String.fromCodePoint(0xF092D)

        let tier = signal >= 0.75 ? 3
                 : signal >= 0.50 ? 2
                 : signal >= 0.25 ? 1
                 : 0
        return String.fromCodePoint(0xF091F + tier*3)
    }

    // Las conexiones pedidas desde el menú (contraseñas, redes empresariales, avisos de
    // fallo) están en services/NetworkMonitor.qml, que no se destruye con la barra: así
    // una conexión a medias no se corta si la barra se vuelve a crear. Aquí solo se pinta.
    Binding {
        target: NetworkMonitor
        property: "menuOpen"
        value: menu.visible
    }

    BarIcon {
        id: iconText
        text: root.icon
        color: (root.wiredConnected || Networking.wifiEnabled) ? Theme.textActive : Theme.textDisabled
        tooltip: menu.visible ? ""
               : root.wiredConnected ? "Conectado por cable"
               : !Networking.wifiEnabled ? "Wifi apagado"
               : !root.active ? "Wifi: sin conexión"
               : root.active.name + " · señal " + Math.round(root.signal * 100) + " %"
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) Networking.wifiEnabled = !Networking.wifiEnabled   // Clic derecho: enciende/apaga el wifi
            else menu.toggle()
        }
    }

    BarPopup {
        id: menu
        anchorItem: iconText

        implicitWidth: 260
        implicitHeight: Math.max(40, listCol.implicitHeight + 16)

        onVisibleChanged: {
            if (root.wifiDevice) root.wifiDevice.scannerEnabled = visible   // Escanea mientras está abierto: al abrir fuerza un escaneo y al cerrar deja de escanear (ahorra batería)
            if (!visible) { NetworkMonitor.expandedNetwork = null; NetworkMonitor.connectError = ""; NetworkMonitor.eapUnverified = null }
        }

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
                    readonly property bool eap: NetworkMonitor.isEap(modelData)

                    function submit() {
                        if (eap) NetworkMonitor.tryConnectEap(modelData.name, userInput.text, pskInput.text, true)
                        else NetworkMonitor.tryConnect(modelData, pskInput.text)
                        pskInput.text = ""               // Que la contraseña no se quede en el campo (si falla, se vuelve a escribir)
                    }

                    Connections {                        // Avisa si falla la conexión (contraseña mal, red que no responde...)
                        target: delegateRoot.modelData
                        function onConnectionFailed(reason) { NetworkMonitor.connectionFailed(delegateRoot.modelData, reason) }
                    }

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
                                      + ((NetworkMonitor.eapRunning && NetworkMonitor.eapNetwork === modelData.name)
                                         || (modelData.stateChanging && !modelData.connected) ? " · conectando…" : "")
                                color: modelData.connected ? Theme.textSelected : Theme.textActive
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: modelData.security !== WifiSecurityType.Open
                                text: String.fromCodePoint(0xF033E)    // lock (Nerd Font, con el color del tema; antes un emoji 🔒)
                                color: modelData.connected ? Theme.textSelected : Theme.textActive   // Como el nombre de la red
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
                                    NetworkMonitor.connectKnown(modelData)
                                } else {
                                    NetworkMonitor.expandedNetwork = (NetworkMonitor.expandedNetwork === modelData) ? null : modelData
                                }
                            }
                        }
                    }

                    Rectangle {                          // Usuario: solo en redes empresariales
                        Layout.fillWidth: true
                        visible: NetworkMonitor.expandedNetwork === modelData && delegateRoot.eap
                        implicitHeight: 22
                        radius: 4
                        color: Theme.background
                        border.color: Theme.border

                        TextInput {
                            id: userInput
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.textActive
                            focus: NetworkMonitor.expandedNetwork === modelData && delegateRoot.eap
                            KeyNavigation.tab: pskInput
                            onAccepted: pskInput.forceActiveFocus()

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !parent.text
                                text: "Usuario"
                                color: Theme.textDisabled
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: NetworkMonitor.expandedNetwork === modelData
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
                                focus: NetworkMonitor.expandedNetwork === modelData && !delegateRoot.eap
                                onAccepted: delegateRoot.submit()

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: delegateRoot.eap && !parent.text
                                    text: "Contraseña"
                                    color: Theme.textDisabled
                                }
                            }
                        }

                        Text {
                            text: "Conectar"
                            color: Theme.textActive

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: delegateRoot.submit()
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: NetworkMonitor.connectError !== ""
                text: NetworkMonitor.connectError
                color: Theme.textDisabled
                wrapMode: Text.Wrap
            }

            Text {
                visible: NetworkMonitor.eapUnverified !== null && !NetworkMonitor.eapRunning
                text: "Conectar sin verificar"
                color: Theme.textActive

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: {
                        const d = NetworkMonitor.eapUnverified
                        NetworkMonitor.tryConnectEap(d.ssid, d.identity, d.password, false)
                    }
                }
            }
        }
    }
}
