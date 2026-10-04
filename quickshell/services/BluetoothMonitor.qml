pragma Singleton
import Quickshell
import Quickshell.Bluetooth
import QtQuick

// Vigilancia de los dispositivos Bluetooth: emparejar y marcar de confianza, avisar de
// los que se han quedado sin clave y repararlos. Lo usa el icono de la barra
// (bar/Bluetooths.qml), que solo pinta y llama a estas funciones. Está aquí y no en el
// icono porque la barra se destruye y se vuelve a crear al cerrar la tapa o cambiar de
// monitor: con todo esto dentro se perdía el historial de cada dispositivo y se cortaba
// una reparación o un emparejamiento a medias.
//
// No se repasan los dispositivos cada pocos segundos: cada uno avisa de sus cambios
// (ver "Avisos de cada dispositivo", al final) y se reacciona en el momento.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter               // null si el equipo no tiene Bluetooth
    readonly property bool powered: adapter ? adapter.enabled : false     // radio encendida/apagada
    property bool menuOpen: false       // El menú de Bluetooth de la barra está abierto (y escaneando); lo pone bar/Bluetooths.qml

    // Historial de cada dispositivo (address -> { prevState, prevPairing, lastNotify, warnedUnbonded }):
    // el estado anterior, para saber de dónde viene cada cambio
    property var deviceMonitor: ({})

    // El dispositivo con esa dirección, o null si el adaptador ya no lo tiene (o no hay adaptador)
    function deviceByAddress(address) {
        return root.adapter?.devices.values.find(d => d.address === address) ?? null
    }

    function monitorFor(dev) {
        let m = root.deviceMonitor[dev.address]
        if (!m) {
            m = { prevState: dev.state, prevPairing: dev.pairing, lastNotify: 0 }   // primera vez que vemos este dispositivo en este arranque
            root.deviceMonitor[dev.address] = m
        }
        return m
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
    property var repairNeeded: []      // addresses con el botón "Reparar" visible
    property var repairingAddrs: []    // addresses con una reparación en curso ahora mismo

    function flagRepairNeeded(dev) {
        if (!root.repairNeeded.includes(dev.address))          // evita duplicados en la lista
            root.repairNeeded = [...root.repairNeeded, dev.address]  // reasignar el array entero para que QML detecte el cambio
        NotificationCenter.notify("Bluetooth", "", "Bluetooth: re-emparejamiento necesario",
            dev.name + " perdió la clave de emparejamiento. Ponlo en modo pairing y pulsa \"Reparar\" en el menú de Bluetooth.")
    }

    function clearRepairNeeded(address) {
        if (root.repairNeeded.includes(address))
            root.repairNeeded = root.repairNeeded.filter(a => a !== address)  // igual: reasignar para notificar el cambio
    }

    // Ha cambiado el estado de conexión de un dispositivo. Como llega cada cambio (no una
    // foto cada 2 s, como antes), tampoco se escapa un intento fallido que dure muy poco.
    function stateChanged(dev) {
        const m = root.monitorFor(dev)
        if (m.prevState === BluetoothDeviceState.Connecting                  // intentó conectar...
            && dev.state === BluetoothDeviceState.Disconnected               // ...y volvió a desconectado sin pasar por Connected
            && dev.paired) {                                                 // solo nos interesa si ya estaba emparejado (key vieja)
            const now = Date.now()
            if (now - m.lastNotify > 5 * 60 * 1000) {                         // cooldown de 5 min para no spamear notificaciones
                m.lastNotify = now
                root.flagRepairNeeded(dev)
            }
        }
        if (dev.state === BluetoothDeviceState.Connected) root.clearRepairNeeded(dev.address)  // se arregló solo (o ya no hace falta avisar)
        m.prevState = dev.state
    }

    // --- Confianza automática al emparejar desde el widget ---
    // Sin agente de BlueZ, un dispositivo emparejado pero no "trusted" no
    // puede abrir perfiles por su cuenta (p.ej. los auriculares conectando el
    // HFP): BlueZ no tiene a quién pedir autorización y lo rechaza, y el
    // dispositivo acaba desconectándose. Por eso los que se emparejan desde
    // aquí se marcan como de confianza. Solo los que pide el usuario desde el
    // menú, no cualquiera que acabe emparejado: con el adaptador siempre en
    // modo pairable (ver ensurePairable) un
    // emparejamiento entrante ajeno no debe llevarse la confianza gratis.
    property var pendingTrust: []   // addresses emparejándose desde el widget, a marcar como trusted cuando cuaje

    function pairAndTrust(dev) {
        if (!root.pendingTrust.includes(dev.address))
            root.pendingTrust = [...root.pendingTrust, dev.address]
        root.ensurePairable()   // por si BlueZ lo acaba de quitar: sin esto la clave no se guardaría
        dev.pair()
    }

    // Ha cambiado "paired" o "pairing" de un dispositivo
    function pairingChanged(dev) {
        const m = root.monitorFor(dev)
        if (root.pendingTrust.includes(dev.address)) {
            if (dev.paired) {
                dev.trusted = true                                          // emparejado desde el widget: de confianza
                root.pendingTrust = root.pendingTrust.filter(a => a !== dev.address)
            } else if (m.prevPairing && !dev.pairing) {
                pendingCheck.restart()                                      // el pairing ha terminado sin emparejar... de momento (ver pendingCheck)
            }
        }
        m.prevPairing = dev.pairing
        unbondedCheck.restart()
    }

    // Al terminar un pairing, "pairing" y "paired" pueden llegar por separado: si llega
    // primero el fin del pairing, parecería que ha fallado. Se espera un momento y solo
    // entonces se olvidan los pendientes que de verdad no se han emparejado.
    Timer {
        id: pendingCheck
        interval: 1500
        onTriggered: {
            root.pendingTrust = root.pendingTrust.filter(addr => {
                const dev = root.deviceByAddress(addr)
                return dev && (dev.pairing || dev.paired)                   // el pairing terminó sin cuajar: se olvida el pendiente
            })
        }
    }

    // --- Adaptador siempre en modo "pairable" ---
    // Si el adaptador no está en modo "pairable" (BlueZ lo deja así cuando no
    // hay ningún agente registrado, y Quickshell no registra ninguno), el
    // pairing sale adelante pero sin guardar la clave: el dispositivo queda
    // Paired pero no Bonded. Funciona mientras dura la conexión, pero al
    // desconectarse BlueZ lo olvida y ya no se puede reconectar. Equivale a
    // AlwaysPairable = true en /etc/bluetooth/main.conf, pero sin tocar
    // archivos del sistema: la propiedad Pairable del adaptador se puede
    // cambiar sin root. BlueZ la vuelve a poner a false al reiniciar el
    // servicio o el adaptador, por eso se reimpone cada vez que cambia.
    function ensurePairable() {
        if (root.adapter && root.adapter.enabled && !root.adapter.pairable)
            root.adapter.pairable = true
    }

    Component.onCompleted: ensurePairable()
    onAdapterChanged: ensurePairable()              // Aparece el adaptador (al arrancar, o al reiniciar el servicio de Bluetooth)
    Connections {
        target: root.adapter
        function onEnabledChanged() { root.ensurePairable() }      // Se enciende la radio
        function onPairableChanged() { root.ensurePairable() }     // BlueZ lo ha quitado
    }

    // --- Aviso de emparejamientos que BlueZ no guarda ---
    // Con ensurePairable() no debería volver a pasar, pero si algo lo impide
    // (o el dispositivo se emparejó antes de este arreglo) se avisa: el botón
    // "reparar" no sirve aquí, lo que hace falta es olvidarlo y re-emparejar.
    property var unbondedAddrs: []   // addresses emparejadas sin clave guardada (Paired sin Bonded)

    // Paired sin Bonded durante 4 s seguidos sin más cambios, para no saltar en el instante
    // justo en que termina el pairing (la clave se guarda un poco después de emparejar).
    // Se vuelve a contar desde cero con cada cambio de paired/bonded de cualquier dispositivo.
    Timer {
        id: unbondedCheck
        interval: 4000
        onTriggered: {
            const unbondedNow = []   // se recalcula entero (así los que desaparecen salen solos de la lista)
            for (const dev of (root.adapter ? root.adapter.devices.values : [])) {
                if (!dev.paired || dev.bonded) continue
                unbondedNow.push(dev.address)
                const m = root.monitorFor(dev)
                if (!m.warnedUnbonded) {                                     // una sola notificación por dispositivo y arranque
                    m.warnedUnbonded = true
                    NotificationCenter.notify("Bluetooth", "", "Bluetooth: emparejamiento no guardado",
                        dev.name + " se ha emparejado sin guardar la clave: al desconectarse se olvidará y no podrá reconectarse. Olvídalo y vuelve a emparejarlo desde el menú.")
                }
            }
            if (unbondedNow.join() !== root.unbondedAddrs.join())   // reasignar solo si cambió, para no redibujar el menú
                root.unbondedAddrs = unbondedNow
        }
    }

    // --- Reparación ---
    // Disparado a mano desde el botón "Reparar": olvida el dispositivo y
    // re-empareja. Solo puede tener éxito si el dispositivo ya está
    // anunciándose (por eso hace falta ponerlo en modo pairing antes).
    function repairDevice(address) {
        if (root.repairingAddrs.includes(address)) return   // ya hay una reparación en curso para este dispositivo
        const dev = root.deviceByAddress(address)
        if (!dev) return
        root.repairingAddrs = [...root.repairingAddrs, address]
        root.adapter.discovering = true   // necesario para volver a ver el dispositivo anunciándose tras el forget()
        dev.forget()                      // borra el link key viejo; dispara repairTimer para reintentar el pairing
        repairTimer.address = address
        repairTimer.restart()
    }

    Timer {
        id: repairTimer
        interval: 800   // pequeño margen tras el forget() antes de intentar volver a emparejar
        property string address: ""
        onTriggered: {
            const dev = root.deviceByAddress(address)
            if (dev) root.pairAndTrust(dev)   // solo tiene éxito si el dispositivo sigue anunciándose (modo pairing)
            pairWatch.address = address
            pairWatch.restart()
        }
    }

    Timer {
        id: pairWatch
        interval: 8000   // tiempo dado al pairing (incluye confirmación de passkey) antes de comprobar el resultado
        property string address: ""
        onTriggered: {
            const dev = root.deviceByAddress(pairWatch.address)
            if (dev && dev.paired) dev.connect()                 // el pairing sí cuajó: ya se puede conectar
            if (root.adapter) root.adapter.discovering = root.menuOpen  // deja el escaneo como estaba según el menú
            root.repairingAddrs = root.repairingAddrs.filter(a => a !== pairWatch.address)
            root.clearRepairNeeded(pairWatch.address)   // se intentó; si falló, stateChanged() lo volverá a marcar
        }
    }

    // --- Avisos de cada dispositivo ---
    // Un Connections por cada dispositivo que conoce el adaptador: el Instantiator crea uno
    // al aparecer un dispositivo y lo quita al desaparecer. Sustituye al Timer que repasaba
    // todos los dispositivos cada 2 s mientras la radio estaba encendida.
    Instantiator {
        model: root.adapter ? root.adapter.devices : []
        delegate: Connections {
            required property BluetoothDevice modelData
            target: modelData

            Component.onCompleted: {                    // Dispositivo nuevo (o todos, al arrancar)
                root.monitorFor(modelData)
                unbondedCheck.restart()
            }
            function onStateChanged() { root.stateChanged(modelData) }
            function onPairedChanged() { root.pairingChanged(modelData) }
            function onPairingChanged() { root.pairingChanged(modelData) }
            function onBondedChanged() { unbondedCheck.restart() }
        }
    }
}
