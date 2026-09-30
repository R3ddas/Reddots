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
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter               // null si el equipo no tiene Bluetooth
    readonly property bool powered: adapter ? adapter.enabled : false     // radio encendida/apagada
    property bool menuOpen: false       // El menú de Bluetooth de la barra está abierto (y escaneando); lo pone bar/Bluetooths.qml

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
        root.ensurePairable()   // por si el timer aún no lo ha reimpuesto: sin esto la clave no se guardaría
        dev.pair()
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
    // servicio o el adaptador, por eso se reimpone en cada pasada.
    function ensurePairable() {
        if (root.adapter && root.adapter.enabled && !root.adapter.pairable)
            root.adapter.pairable = true
    }

    // --- Aviso de emparejamientos que BlueZ no guarda ---
    // Con ensurePairable() no debería volver a pasar, pero si algo lo impide
    // (o el dispositivo se emparejó antes de este arreglo) se avisa: el botón
    // "reparar" no sirve aquí, lo que hace falta es olvidarlo y re-emparejar.
    property var unbondedAddrs: []   // addresses emparejadas sin clave guardada (Paired sin Bonded)

    function checkDevices() {
        if (!root.adapter) return
        root.ensurePairable()
        const now = Date.now()
        const unbondedNow = []   // se recalcula entero en cada pasada (así los que desaparecen salen solos de la lista)
        for (const dev of root.adapter.devices.values) {
            const addr = dev.address
            let m = root.deviceMonitor[addr]
            if (!m) {
                m = { prevState: dev.state, prevPairing: dev.pairing, lastNotify: 0 }   // primera vez que vemos este dispositivo en este arranque
                root.deviceMonitor[addr] = m
            }

            if (root.pendingTrust.includes(addr)) {
                if (dev.paired) {
                    dev.trusted = true                                              // emparejado desde el widget: de confianza
                    root.pendingTrust = root.pendingTrust.filter(a => a !== addr)
                } else if (m.prevPairing && !dev.pairing) {
                    root.pendingTrust = root.pendingTrust.filter(a => a !== addr)   // el pairing terminó sin cuajar: se olvida el pendiente
                }
            }
            m.prevPairing = dev.pairing

            // Paired sin Bonded en dos pasadas seguidas (4 s), para no saltar
            // en el instante justo en que termina el pairing
            const unbonded = dev.paired && !dev.bonded
            if (unbonded && m.prevUnbonded) {
                unbondedNow.push(addr)
                if (!m.warnedUnbonded) {                                     // una sola notificación por dispositivo y arranque
                    m.warnedUnbonded = true
                    Quickshell.execDetached(["notify-send", "-u", "normal", "-a", "Bluetooth",
                        "Bluetooth: emparejamiento no guardado",
                        dev.name + " se ha emparejado sin guardar la clave: al desconectarse se olvidará y no podrá reconectarse. Olvídalo y vuelve a emparejarlo desde el menú."])
                }
            }
            m.prevUnbonded = unbonded

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
        if (unbondedNow.join() !== root.unbondedAddrs.join())   // reasignar solo si cambió, para no redibujar el menú cada 2 s
            root.unbondedAddrs = unbondedNow
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
            const dev = root.adapter?.devices.values.find(d => d.address === pairWatch.address)
            if (dev && dev.paired) dev.connect()                 // el pairing sí cuajó: ya se puede conectar
            if (root.adapter) root.adapter.discovering = root.menuOpen  // deja el escaneo como estaba según el menú
            root.repairingAddrs = root.repairingAddrs.filter(a => a !== pairWatch.address)
            root.clearRepairNeeded(pairWatch.address)   // se intentó; si falló, checkDevices lo volverá a marcar
        }
    }
}
