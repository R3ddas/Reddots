import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts


ColumnLayout {
    id: root
    spacing: 6

    readonly property var adapter: Bluetooth.defaultAdapter               // null si el equipo no tiene Bluetooth
    readonly property bool powered: adapter ? adapter.enabled : false     // radio encendida/apagada
    readonly property var active: adapter                                 // primer dispositivo conectado (para el icono)
    ? adapter.devices.values.find(d => d.connected) ?? null
    : null

    // Oculta dispositivos anónimos (sin nombre anunciado: BlueZ les pone como
    // "nombre" su propia MAC, pero con guiones en vez de dos puntos, por eso
    // no basta comparar con el address tal cual) para no llenar el menú de
    // balizas BLE ajenas; los ya emparejados se muestran siempre aunque no
    // tengan nombre.
    readonly property var macNamePattern: /^[0-9A-Fa-f]{2}(-[0-9A-Fa-f]{2}){5}$/  // "AA-BB-CC-DD-EE-FF"
    readonly property var visibleDevices: adapter
    ? adapter.devices.values.filter(d => d.paired || (d.name && !root.macNamePattern.test(d.name)))  // paired siempre visible; el resto solo si tiene nombre real
    : []

    readonly property string icon: {
        if (!powered) return String.fromCodePoint(0xF00B2)  // bluetooth-off
            if (!active)  return String.fromCodePoint(0xF00AF)  // bluetooth
                return String.fromCodePoint(0xF00B1)                // bluetooth-connect
    }

    // --- Aviso + reparación manual de dispositivos con key desincronizada ---
    // Si un dispositivo ya emparejado falla al conectar (pasa a Connecting y
    // vuelve a Disconnected sin llegar a Connected), es la señal típica de
    // "br-connection-key-missing": el link key local ya no coincide con el
    // del dispositivo. El único arreglo real es olvidar y re-emparejar, y eso
    // solo funciona si el dispositivo está anunciándose (modo pairing) justo
    // en ese momento. Como no podemos saber cuándo el usuario habrá puesto el
    // dispositivo en modo pairing, en vez de reintentar a ciegas en segundo
    // plano avisamos por notificación y dejamos un botón "Reparar" en el
    // menú para dispararlo en el momento justo.
    property var deviceMonitor: ({})   // address -> { prevState, lastNotify }, historial interno para detectar el fallo
    property var repairNeeded: []      // addresses con el botón "Reparar" visible
    property var repairingAddrs: []    // addresses con una reparación en curso ahora mismo

    function flagRepairNeeded(dev) {
        if (!root.repairNeeded.includes(dev.address))          // evita duplicados en la lista
            root.repairNeeded = [...root.repairNeeded, dev.address]  // reasignar el array entero para que QML detecte el cambio
        Quickshell.execDetached(["notify-send", "-u", "normal", "-a", "Bluetooth",     // Quickshell no expone Notify() a QML, así que se usa el binario
            "Bluetooth: re-emparejamiento necesario",
            dev.name + " perdió la clave de emparejamiento. Ponlo en modo pairing y pulsa \"Reparar\" en el menú de Bluetooth."])
    }

    function clearRepairNeeded(address) {
        if (root.repairNeeded.includes(address))
            root.repairNeeded = root.repairNeeded.filter(a => a !== address)  // igual: reasignar para notificar el cambio
    }

    function checkDevices() {
        if (!root.adapter) return
        const now = Date.now()
        for (const dev of root.adapter.devices.values) {
            const addr = dev.address
            let m = root.deviceMonitor[addr]
            if (!m) {
                m = { prevState: dev.state, lastNotify: 0 }   // primera vez que vemos este dispositivo en este arranque
                root.deviceMonitor[addr] = m
            }

            if (m.prevState === BluetoothDeviceState.Connecting              // intentó conectar...
                && dev.state === BluetoothDeviceState.Disconnected           // ...y volvió a desconectado sin pasar por Connected
                && dev.paired) {                                             // solo nos interesa si ya estaba emparejado (key vieja)
                if (now - m.lastNotify > 5 * 60 * 1000) {                     // cooldown de 5 min para no spamear notificaciones
                    m.lastNotify = now
                    root.flagRepairNeeded(dev)
                }
            }
            if (dev.state === BluetoothDeviceState.Connected) root.clearRepairNeeded(addr)  // se arregló solo (o ya no hace falta avisar)
            m.prevState = dev.state
        }
    }

    // Disparado a mano desde el botón "Reparar": olvida el dispositivo y
    // re-empareja. Solo puede tener éxito si el dispositivo ya está
    // anunciándose (por eso hace falta ponerlo en modo pairing antes).
    function repairDevice(address) {
        if (root.repairingAddrs.includes(address)) return   // ya hay una reparación en curso para este dispositivo
        const dev = root.adapter?.devices.values.find(d => d.address === address)
        if (!dev) return
        root.repairingAddrs = [...root.repairingAddrs, address]
        root.adapter.discovering = true   // necesario para volver a ver el dispositivo anunciándose tras el forget()
        dev.forget()                      // borra el link key viejo; dispara repairTimer para reintentar el pairing
        repairTimer.address = address
        repairTimer.restart()
    }

    Timer {
        id: watchTimer
        interval: 2000        // cada 2s es suficiente para pillar el Connecting->Disconnected sin gastar CPU
        running: root.powered
        repeat: true
        onTriggered: root.checkDevices()
    }

    Timer {
        id: repairTimer
        interval: 800   // pequeño margen tras el forget() antes de intentar volver a emparejar
        property string address: ""
        onTriggered: {
            const dev = root.adapter?.devices.values.find(d => d.address === address)
            if (dev) dev.pair()   // solo tiene éxito si el dispositivo sigue anunciándose (modo pairing)
            pairWatch.address = address
            pairWatch.restart()
        }
    }

    Timer {
        id: pairWatch
        interval: 8000   // tiempo dado al pairing (incluye confirmación de passkey) antes de comprobar el resultado
        property string address: ""
        onTriggered: {
            const dev = root.adapter?.devices.values.find(d => d.address === pairWatch.address)
            if (dev && dev.paired) dev.connect()                 // el pairing sí cuajó: ya se puede conectar
            if (root.adapter) root.adapter.discovering = menu.visible  // deja el escaneo como estaba según el menú
            root.repairingAddrs = root.repairingAddrs.filter(a => a !== pairWatch.address)
            root.clearRepairNeeded(pairWatch.address)   // se intentó; si falló, checkDevices lo volverá a marcar
        }
    }

    BarIcon {
        id: iconText
        text: root.icon
        color: root.powered ? Theme.textActive : Theme.textDisabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.LeftButton) menu.toggle()                             // clic izq: abre/cierra el menú de dispositivos
            else if (root.adapter) root.adapter.enabled = !root.adapter.enabled          // clic der: enciende/apaga el radio Bluetooth
        }
    }

    BarPopup {
        id: menu
        anchorItem: iconText

        implicitWidth: 240
        implicitHeight: Math.max(40, listCol.implicitHeight + 16)

        // Escanea mientras el menú está abierto; se detiene al cerrarlo para no gastar batería
        onVisibleChanged: if (root.adapter) root.adapter.discovering = visible

        ColumnLayout {
            id: listCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Text {
                Layout.fillWidth: true
                visible: root.visibleDevices.length === 0   // placeholder solo cuando la lista filtrada está vacía
                text: root.powered ? (root.adapter?.discovering ? "Buscando…" : "Sin dispositivos") : "Bluetooth apagado"
                color: Theme.textDisabled
            }

            Repeater {
                model: root.visibleDevices   // lista ya filtrada, no el modelo crudo del adaptador

                delegate: Rectangle {
                    id: deviceRow
                    required property var modelData
                    readonly property bool needsRepair: root.repairNeeded.includes(modelData.address)   // muestra el botón "reparar"
                    readonly property bool repairing: root.repairingAddrs.includes(modelData.address)   // reparación en curso -> deshabilita el botón

                    Layout.fillWidth: true
                    implicitHeight: 26
                    radius: 4
                    color: deviceMouse.containsMouse ? Theme.surfaceHover : "transparent"

                    Text {
                        id: deviceLabel
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 12 - (deviceRow.needsRepair || deviceRow.repairing ? repairLabel.width + 6 : 0)  // deja hueco al botón "reparar" si está visible
                        text: {
                            const icon = modelData.connected ? "󰂱  "     // auricular conectado
                                : modelData.pairing ? "⏳  "             // emparejando
                                : modelData.paired ? "󰂯  "              // emparejado pero desconectado
                                : "󰂲  "                                 // dispositivo nuevo, sin emparejar
                            const suffix = modelData.paired ? "" : "  (nuevo)"
                            return icon + modelData.name + suffix
                        }
                        color: modelData.connected ? Theme.textActive : Theme.textDisabled
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
                            if (modelData.pairing) modelData.cancelPair()          // click durante el pairing = cancelarlo
                                else if (modelData.connected) modelData.disconnect()
                                else if (modelData.paired) modelData.connect()     // ya conocido: solo reconectar
                                else modelData.pair()                              // desconocido: emparejar por primera vez
                        }
                    }

                    Text {
                        id: repairLabel
                        visible: deviceRow.needsRepair || deviceRow.repairing   // solo aparece cuando hace falta
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        text: deviceRow.repairing ? "reparando…" : "reparar"
                        font.underline: !deviceRow.repairing   // subrayado = clicable; sin subrayar mientras repara
                        color: Theme.textActive

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            enabled: !deviceRow.repairing   // evita relanzar la reparación mientras ya hay una en curso
                            onClicked: root.repairDevice(modelData.address)
                        }
                    }
                }
            }
        }
    }
}
