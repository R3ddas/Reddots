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
    readonly property bool powered: adapter ? adapter.enabled : false     // Radio encendida o apagada
    property bool menuOpen: false       // El menú de Bluetooth de la barra está abierto (y buscando); lo pone bar/Bluetooths.qml

    // Historial de cada dispositivo (dirección -> { prevState, prevPairing, lastNotify, warnedUnbonded }):
    // el estado anterior, para saber de dónde viene cada cambio
    property var deviceMonitor: ({})

    // El dispositivo con esa dirección, o null si el adaptador ya no lo tiene (o no hay adaptador)
    function deviceByAddress(address) {
        return root.adapter?.devices.values.find(d => d.address === address) ?? null
    }

    function monitorFor(dev) {
        let m = root.deviceMonitor[dev.address]
        if (!m) {
            m = { prevState: dev.state, prevPairing: dev.pairing, lastNotify: 0 }   // Primera vez que se ve este dispositivo desde que arrancó Quickshell
            root.deviceMonitor[dev.address] = m
        }
        return m
    }

    // --- Aviso y reparación a mano de los dispositivos que han perdido la clave ---
    // Si un dispositivo ya emparejado falla al conectar (pasa a Connecting y vuelve a
    // Disconnected sin llegar a Connected), es la señal típica de "br-connection-key-missing":
    // la clave de emparejamiento que guarda el equipo ya no coincide con la del dispositivo.
    // El único arreglo es olvidarlo y volver a emparejarlo, y eso solo funciona si el
    // dispositivo se está anunciando (en modo de emparejamiento) justo en ese momento. Como
    // no se puede saber cuándo lo habrá puesto así el usuario, en vez de reintentar a ciegas
    // en segundo plano se avisa con una notificación y se deja un botón "reparar" en el menú
    // para lanzarlo en el momento justo.
    property var repairNeeded: []      // Direcciones con el botón "reparar" a la vista
    property var repairingAddrs: []    // Direcciones con una reparación en marcha

    function flagRepairNeeded(dev) {
        if (!root.repairNeeded.includes(dev.address))          // Sin repetidos en la lista
            root.repairNeeded = [...root.repairNeeded, dev.address]  // Lista nueva: si se cambia por dentro, QML no se entera
        NotificationCenter.notify("Bluetooth", "", "Bluetooth: hay que volver a emparejarlo",
            dev.name + " ha perdido la clave de emparejamiento. Ponlo en modo de emparejamiento y pulsa \"reparar\" en el menú de Bluetooth.")
    }

    function clearRepairNeeded(address) {
        if (root.repairNeeded.includes(address))
            root.repairNeeded = root.repairNeeded.filter(a => a !== address)  // También lista nueva, por lo mismo
    }

    // Ha cambiado el estado de conexión de un dispositivo. Como llega cada cambio (no una
    // foto cada 2 s, como antes), tampoco se escapa un intento fallido que dure muy poco.
    function stateChanged(dev) {
        const m = root.monitorFor(dev)
        if (m.prevState === BluetoothDeviceState.Connecting                  // Intentó conectar...
            && dev.state === BluetoothDeviceState.Disconnected               // ...y volvió a desconectado sin pasar por Connected
            && dev.paired) {                                                 // Solo si ya estaba emparejado (clave vieja)
            const now = Date.now()
            if (now - m.lastNotify > 5 * 60 * 1000) {                         // Como mucho un aviso cada 5 min, para no llenar la pantalla de notificaciones
                m.lastNotify = now
                root.flagRepairNeeded(dev)
            }
        }
        if (dev.state === BluetoothDeviceState.Connected) root.clearRepairNeeded(dev.address)  // Se ha arreglado solo (o ya no hace falta avisar)
        m.prevState = dev.state
    }

    // --- De confianza al emparejar desde el menú ---
    // Sin un agente de BlueZ, un dispositivo emparejado pero que no es de confianza
    // ("trusted") no puede abrir perfiles por su cuenta (p.ej. unos auriculares conectando
    // el HFP): BlueZ no tiene a quién pedir permiso, lo rechaza y el dispositivo acaba
    // desconectándose. Por eso los que se emparejan desde aquí se marcan de confianza. Solo
    // los que pide el usuario desde el menú, no cualquiera que acabe emparejado: con el
    // adaptador siempre dispuesto a emparejar (ver ensurePairable), un emparejamiento ajeno
    // que llegue de fuera no debe llevarse la confianza gratis.
    property var pendingTrust: []   // Direcciones que se están emparejando desde el menú, a marcar de confianza cuando terminen

    function pairAndTrust(dev) {
        if (!root.pendingTrust.includes(dev.address))
            root.pendingTrust = [...root.pendingTrust, dev.address]
        root.ensurePairable()   // Por si BlueZ lo acaba de quitar: sin esto la clave no se guardaría
        dev.pair()
    }

    // Ha cambiado "paired" o "pairing" de un dispositivo
    function pairingChanged(dev) {
        const m = root.monitorFor(dev)
        if (root.pendingTrust.includes(dev.address)) {
            if (dev.paired) {
                dev.trusted = true                                          // Emparejado desde el menú: de confianza
                root.pendingTrust = root.pendingTrust.filter(a => a !== dev.address)
            } else if (m.prevPairing && !dev.pairing) {
                pendingCheck.restart()                                      // El emparejamiento ha terminado sin emparejar... de momento (ver pendingCheck)
            }
        }
        m.prevPairing = dev.pairing
        unbondedCheck.restart()
    }

    // Al terminar un emparejamiento, "pairing" y "paired" pueden llegar por separado: si llega
    // primero el fin del emparejamiento, parecería que ha fallado. Se espera un momento y
    // solo entonces se olvidan los pendientes que de verdad no se han emparejado.
    Timer {
        id: pendingCheck
        interval: 1500
        onTriggered: {
            root.pendingTrust = root.pendingTrust.filter(addr => {
                const dev = root.deviceByAddress(addr)
                return dev && (dev.pairing || dev.paired)                   // Si terminó sin emparejar, se olvida el pendiente
            })
        }
    }

    // --- Adaptador siempre dispuesto a emparejar ("pairable") ---
    // Si el adaptador no está en modo "pairable" (BlueZ lo deja así cuando no hay ningún
    // agente registrado, y Quickshell no registra ninguno), el emparejamiento sale adelante
    // pero sin guardar la clave: el dispositivo queda emparejado ("Paired") pero sin clave
    // guardada ("Bonded"). Funciona mientras dura la conexión, pero al desconectarse BlueZ
    // lo olvida y ya no se puede volver a conectar. Equivale a AlwaysPairable = true en
    // /etc/bluetooth/main.conf, pero sin tocar archivos del sistema: la propiedad Pairable
    // del adaptador se puede cambiar sin root. BlueZ la vuelve a poner a false al reiniciar
    // el servicio o el adaptador, por eso se vuelve a poner cada vez que cambia.
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
    // Con ensurePairable() no debería volver a pasar, pero si algo lo impide (o el
    // dispositivo se emparejó antes de este arreglo) se avisa: aquí el botón "reparar" no
    // sirve, lo que hace falta es olvidarlo y volver a emparejarlo.
    property var unbondedAddrs: []   // Direcciones emparejadas sin clave guardada ("Paired" sin "Bonded")

    // Emparejado sin clave guardada durante 4 s seguidos sin más cambios, para no saltar en
    // el instante justo en que termina el emparejamiento (la clave se guarda un poco después).
    // Se vuelve a contar desde cero con cada cambio de paired/bonded de cualquier dispositivo.
    Timer {
        id: unbondedCheck
        interval: 4000
        onTriggered: {
            const unbondedNow = []   // Se recalcula entera (así los que desaparecen salen solos de la lista)
            for (const dev of (root.adapter ? root.adapter.devices.values : [])) {
                if (!dev.paired || dev.bonded) continue
                unbondedNow.push(dev.address)
                const m = root.monitorFor(dev)
                if (!m.warnedUnbonded) {                                     // Un solo aviso por dispositivo desde que arrancó Quickshell
                    m.warnedUnbonded = true
                    NotificationCenter.notify("Bluetooth", "", "Bluetooth: emparejamiento no guardado",
                        dev.name + " se ha emparejado sin guardar la clave: al desconectarse se olvidará y no podrá volver a conectarse. Olvídalo y vuelve a emparejarlo desde el menú.")
                }
            }
            if (unbondedNow.join() !== root.unbondedAddrs.join())   // Solo si ha cambiado, para no redibujar el menú
                root.unbondedAddrs = unbondedNow
        }
    }

    // --- Reparación ---
    // Se lanza a mano desde el botón "reparar": olvida el dispositivo y lo vuelve a
    // emparejar. Solo sale bien si el dispositivo ya se está anunciando (por eso hay que
    // ponerlo antes en modo de emparejamiento).
    function repairDevice(address) {
        if (root.repairingAddrs.includes(address)) return   // Ya hay una reparación en marcha para este dispositivo
        const dev = root.deviceByAddress(address)
        if (!dev) return
        root.repairingAddrs = [...root.repairingAddrs, address]
        root.adapter.discovering = true   // Hace falta buscar para volver a ver el dispositivo anunciándose tras el forget()
        dev.forget()                      // Borra la clave vieja; repairTimer vuelve a intentar el emparejamiento
        repairTimer.address = address
        repairTimer.restart()
    }

    Timer {
        id: repairTimer
        interval: 800   // Un poco de margen tras el forget() antes de intentar volver a emparejar
        property string address: ""
        onTriggered: {
            const dev = root.deviceByAddress(address)
            if (dev) root.pairAndTrust(dev)   // Solo sale bien si el dispositivo sigue anunciándose (en modo de emparejamiento)
            pairWatch.address = address
            pairWatch.restart()
        }
    }

    Timer {
        id: pairWatch
        interval: 8000   // Tiempo que se le da al emparejamiento (incluida la confirmación del código) antes de mirar cómo ha ido
        property string address: ""
        onTriggered: {
            const dev = root.deviceByAddress(pairWatch.address)
            if (dev && dev.paired) dev.connect()                 // Se ha emparejado: ya se puede conectar
            if (root.adapter) root.adapter.discovering = root.menuOpen  // Deja la búsqueda como diga el menú (abierto: buscando)
            root.repairingAddrs = root.repairingAddrs.filter(a => a !== pairWatch.address)
            root.clearRepairNeeded(pairWatch.address)   // Ya se ha intentado; si ha fallado, stateChanged() lo volverá a marcar
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
