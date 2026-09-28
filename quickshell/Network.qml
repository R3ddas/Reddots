// Recursos: https://www.youtube.com/watch?v=Vlpyz4c4Xdw
// https://www.nerdfonts.com/

import Quickshell
import Quickshell.Networking  // Para la información de las conexiones
import Quickshell.Io          // Para lanzar nmcli en las redes con usuario y contraseña
import QtQuick
import QtQuick.Layouts          // Para usar RowLayout o ColumnLayout

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

    function tryConnect(network, psk) {          // Conecta con contraseña y cierra el campo de texto
        network.connectWithPsk(psk)
        menu.expandedNetwork = null
    }

    property string eapNetwork: ""               // Red empresarial a la que se está conectando
    property string eapError: ""                 // Mensaje del último intento fallido

    function isEap(network) {                    // Redes WPA/WPA2-Enterprise (eduroam...): piden usuario además de contraseña
        return network.security === WifiSecurityType.Wpa2Eap || network.security === WifiSecurityType.WpaEap
    }

    // Quickshell solo sabe conectar con PSK, así que el perfil 802.1X (PEAP + MSCHAPv2, lo habitual en eduroam)
    // se crea con nmcli. Si no llega a conectar se borra, para poder reintentarlo con otros datos.
    function tryConnectEap(network, identity, password) {
        eapNetwork = network.name
        eapError = ""
        eapProc.command = ["sh", "-c",
            "nmcli connection add type wifi con-name \"$1\" ssid \"$1\" wifi-sec.key-mgmt wpa-eap"
            + " 802-1x.eap peap 802-1x.phase2-auth mschapv2 802-1x.identity \"$2\" 802-1x.password \"$3\" >/dev/null"
            + " && { nmcli connection up id \"$1\" >/dev/null || { nmcli connection delete id \"$1\" >/dev/null; exit 1; }; }",
            "sh", network.name, identity, password]
        eapProc.running = true
        menu.expandedNetwork = null
    }

    Process {
        id: eapProc
        onExited: exitCode => { if (exitCode !== 0) root.eapError = "No se pudo conectar a " + root.eapNetwork + ": revisa usuario y contraseña" }
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
        property var expandedNetwork: null      // Red a la espera de que se introduzca la contraseña


        implicitWidth: 260
        implicitHeight: Math.max(40, listCol.implicitHeight + 16)

        onVisibleChanged: {
            if (root.wifiDevice) root.wifiDevice.scannerEnabled = visible   // Escanea mientras está abierto: al abrir fuerza un escaneo y al cerrar deja de escanear (ahorra batería)
            if (!visible) { expandedNetwork = null; root.eapError = "" }
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
                    readonly property bool eap: root.isEap(modelData)

                    function submit() {
                        if (eap) {
                            root.tryConnectEap(modelData, userInput.text, pskInput.text)
                            pskInput.text = ""           // Que la contraseña no se quede en el campo
                        } else {
                            root.tryConnect(modelData, pskInput.text)
                        }
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
                                      + (eapProc.running && root.eapNetwork === modelData.name ? " · conectando…" : "")
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

                    Rectangle {                          // Usuario: solo en redes empresariales
                        Layout.fillWidth: true
                        visible: menu.expandedNetwork === modelData && delegateRoot.eap
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
                            focus: menu.expandedNetwork === modelData && delegateRoot.eap
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
                                focus: menu.expandedNetwork === modelData && !delegateRoot.eap
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
                visible: root.eapError !== ""
                text: root.eapError
                color: Theme.textDisabled
                wrapMode: Text.Wrap
            }
        }
    }
}
