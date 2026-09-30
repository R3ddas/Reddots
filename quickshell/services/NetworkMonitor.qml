pragma Singleton
import Quickshell
import Quickshell.Networking  // Para conectar a las redes wifi
import Quickshell.Io          // Para lanzar nmcli en las redes con usuario y contraseña
import QtQuick

// Conexiones wifi pedidas desde el menú de la barra (bar/Network.qml, que solo pinta y
// llama a estas funciones): contraseñas, redes empresariales (eduroam...) y los avisos
// cuando algo falla. Está aquí y no en el icono porque la barra se destruye y se vuelve a
// crear al cerrar la tapa o cambiar de monitor: con esto dentro se cortaba a medias la
// conexión a una red empresarial (el script de nmcli moría con la barra) y se perdía el
// aviso de si había fallado.
Singleton {
    id: root

    property bool menuOpen: false                // El menú de wifi está abierto (lo pone bar/Network.qml): los fallos se ven ahí en vez de con una notificación
    property var expandedNetwork: null           // Red con el campo de la contraseña abierto en el menú
    readonly property bool eapRunning: eapProc.running   // Conectando a una red empresarial (el menú pone "conectando…")

    property string connectError: ""             // Mensaje del último intento fallido (con contraseña o empresarial)
    property string pskNetwork: ""               // Red a la que se acaba de mandar una contraseña desde el campo
    property string requestedNetwork: ""         // Red a la que se ha pedido conectar desde el menú (con o sin contraseña)

    // Muestra el fallo en el menú y, si está cerrado (el fallo puede tardar unos segundos en
    // llegar y para entonces ya se ha cerrado), también con una notificación. "hint" es lo que
    // se puede hacer al abrir el menú, solo para la notificación.
    function showError(message, hint) {
        connectError = message
        if (!root.menuOpen)
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
        root.expandedNetwork = null
    }

    // Un intento de conexión wifi ha fallado (lo avisa la propia red, ver el Connections del delegado en bar/Network.qml).
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
            root.expandedNetwork = network                                  // Para escribirla otra vez (se ve al abrir el menú)
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
        root.expandedNetwork = null
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
}
