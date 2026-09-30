// Recursos: https://www.youtube.com/watch?v=Vlpyz4c4Xdw
// https://www.nerdfonts.com/

import Quickshell
import Quickshell.Networking  // Para la información de las conexiones
import Quickshell.Io          // Para lanzar nmcli en las redes con usuario y contraseña
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

    property string connectError: ""             // Mensaje del último intento fallido (con contraseña o empresarial)
    property string pskNetwork: ""               // Red a la que se acaba de mandar una contraseña desde el campo
    property string requestedNetwork: ""         // Red a la que se ha pedido conectar desde el menú (con o sin contraseña)

    // Muestra el fallo en el menú y, si está cerrado (el fallo puede tardar unos segundos en
    // llegar y para entonces ya se ha cerrado), también con una notificación. "hint" es lo que
    // se puede hacer al abrir el menú, solo para la notificación.
    function showError(message, hint) {
        connectError = message
        if (!menu.visible)
            Quickshell.execDetached(["notify-send", "-u", "normal", "-a", "Wifi", "-i", "network-wireless-disconnected",
                "No se pudo conectar", message + (hint ? ".\n" + hint : "")])
    }

    function connectKnown(network) {             // Red ya guardada (o abierta): conecta sin pedir nada
        connectError = ""
        requestedNetwork = network.name
        network.connect()
    }

    function tryConnect(network, psk) {          // Conecta con contraseña y cierra el campo de texto
        connectError = ""
        pskNetwork = network.name
        requestedNetwork = network.name
        network.connectWithPsk(psk)
        menu.expandedNetwork = null
    }

    // Un intento de conexión wifi ha fallado (lo avisa la propia red, ver el Connections del delegado).
    // Con una contraseña recién escrita, lo normal es que esté mal. Si NetworkManager ya ha guardado
    // el perfil con ella, la red pasaría a "conocida" y al pulsarla intentaría otra vez la misma sin
    // volver a pedirla. Por eso se olvida (si llegó a guardarse) y se vuelve a abrir el campo.
    //
    // La señal también llega cuando falla una reconexión automática de NetworkManager (al
    // arrancar, al volver de suspender...): esas se ven en el menú, pero no se notifican, para no
    // llenar la pantalla de avisos que no se han pedido. Solo las que se han pedido desde el menú.
    function connectionFailed(network, reason) {
        const fresh = network.name === pskNetwork
        const requested = network.name === requestedNetwork
        if (fresh) pskNetwork = ""
        if (requested) requestedNetwork = ""
        const why = reason === ConnectionFailReason.WifiAuthTimeout ? "no responde a tiempo"
                  : reason === ConnectionFailReason.WifiNetworkLost ? "se ha perdido la señal"
                  : "revisa la contraseña"                                  // NoSecrets, WifiClientFailed...: casi siempre la contraseña
        const message = "No se pudo conectar a " + network.name + ": " + why
        const retype = fresh && reason !== ConnectionFailReason.WifiNetworkLost && reason !== ConnectionFailReason.WifiAuthTimeout
        if (retype) {
            if (network.known) network.forget()
            menu.expandedNetwork = network                                  // Para escribirla otra vez (se ve al abrir el menú)
        }
        if (requested) showError(message, retype ? "Abre el menú de wifi para escribir otra vez la contraseña." : "")
        else connectError = message
    }

    property string eapNetwork: ""               // Red empresarial a la que se está conectando
    property var eapUnverified: null             // Datos del intento rechazado por el certificado, por si se quiere conectar sin verificar
    property string eapPassword: ""              // Contraseña a la espera de mandársela al script por la entrada estándar (ver eapProc)

    function isEap(network) {                    // Redes WPA/WPA2-Enterprise (eduroam...): piden usuario además de contraseña
        return network.security === WifiSecurityType.Wpa2Eap || network.security === WifiSecurityType.WpaEap
    }

    // Quickshell solo sabe conectar con PSK, así que el perfil 802.1X lo crea el script con nmcli,
    // verificando el certificado del servidor salvo que se pida lo contrario
    function tryConnectEap(ssid, identity, password, verify) {
        eapNetwork = ssid
        connectError = ""
        eapUnverified = verify ? { ssid: ssid, identity: identity, password: password } : null
        eapPassword = password
        eapProc.command = [Quickshell.shellPath("scripts/wifi-eap-connect.sh"), ssid, identity]
                          .concat(verify ? [] : ["--sin-verificar"])
        eapProc.running = true
        menu.expandedNetwork = null
    }

    // La contraseña no va en "command": los argumentos de un proceso los ve cualquiera con "ps"
    // mientras dura. Se le escribe al script por la entrada estándar en cuanto arranca.
    Process {
        id: eapProc
        stdinEnabled: true
        onStarted: {
            write(root.eapPassword + "\n")
            root.eapPassword = ""
        }
        onExited: exitCode => {
            root.eapPassword = ""                                           // Por si no llegó a arrancar
            if (exitCode === 2) {
                root.showError("No se pudo verificar el servidor de " + root.eapNetwork + ": podría ser una red falsa",
                               "Si confías en ella, abre el menú de wifi y pulsa «Conectar sin verificar».")
                return                                                      // Se conservan los datos para "Conectar sin verificar"
            }
            root.eapUnverified = null
            if (exitCode !== 0) root.showError("No se pudo conectar a " + root.eapNetwork + ": revisa usuario y contraseña",
                                               "Abre el menú de wifi para intentarlo otra vez.")
        }
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
            if (!visible) { expandedNetwork = null; root.connectError = ""; root.eapUnverified = null }
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
                        if (eap) root.tryConnectEap(modelData.name, userInput.text, pskInput.text, true)
                        else root.tryConnect(modelData, pskInput.text)
                        pskInput.text = ""               // Que la contraseña no se quede en el campo (si falla, se vuelve a escribir)
                    }

                    Connections {                        // Avisa si falla la conexión (contraseña mal, red que no responde...)
                        target: delegateRoot.modelData
                        function onConnectionFailed(reason) { root.connectionFailed(delegateRoot.modelData, reason) }
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
                                      + ((eapProc.running && root.eapNetwork === modelData.name)
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
                                    root.connectKnown(modelData)
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
                visible: root.connectError !== ""
                text: root.connectError
                color: Theme.textDisabled
                wrapMode: Text.Wrap
            }

            Text {
                visible: root.eapUnverified !== null && !eapProc.running
                text: "Conectar sin verificar"
                color: Theme.textActive

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: {
                        const d = root.eapUnverified
                        root.tryConnectEap(d.ssid, d.identity, d.password, false)
                    }
                }
            }
        }
    }
}
