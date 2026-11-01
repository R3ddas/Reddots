pragma Singleton
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

// Vigilancia de los dispositivos Bluetooth: conectar, emparejar y marcar de confianza,
// avisar de los que se han quedado sin clave y repararlos. Lo usa el icono de la barra
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
    property bool menuOpen: false       // El menú de Bluetooth de la barra está abierto; lo pone bar/Bluetooths.qml

    // Historial de cada dispositivo (dirección -> { prevPairing, lastNotify, warnedUnbonded }):
    // el estado anterior, para saber de dónde viene cada cambio
    property var deviceMonitor: ({})

    // El dispositivo con esa dirección, o null si el adaptador ya no lo tiene (o no hay adaptador)
    function deviceByAddress(address) {
        return root.adapter?.devices.values.find(d => d.address === address) ?? null
    }

    function monitorFor(dev) {
        let m = root.deviceMonitor[dev.address]
        if (!m) {
            m = { prevPairing: dev.pairing, lastNotify: 0 }   // Primera vez que se ve este dispositivo desde que arrancó Quickshell
            root.deviceMonitor[dev.address] = m
        }
        return m
    }

    // --- Búsqueda de dispositivos ---
    // Se busca mientras el menú está abierto, pero no mientras se conecta algo: el adaptador
    // (una Intel AX201, que además comparte radio con el wifi) tiene que repartir el tiempo
    // entre buscar y conectar, y con la búsqueda en marcha la conexión falla mucho más. Una
    // reparación sí necesita buscar (para volver a ver el dispositivo tras olvidarlo), así
    // que manda sobre todo lo demás. Todo cambio de la búsqueda pasa por aquí.
    function updateDiscovery() {
        if (!root.adapter || !root.adapter.enabled) return
        const want = root.repairingAddrs.length > 0
            || (root.menuOpen && root.connectingAddrs.length === 0)
        if (root.adapter.discovering !== want) root.adapter.discovering = want   // Solo si cambia, para no mandar a BlueZ peticiones de más
    }

    onMenuOpenChanged: updateDiscovery()

    // --- Conexión ---
    // Se conecta con busctl en vez de con dev.connect() de Quickshell porque Quickshell no
    // cuenta por qué ha fallado una conexión (solo lo deja en su log). Con el error real
    // se puede distinguir "ha perdido la clave" (br-connection-key-missing, que se arregla
    // con "reparar") de "no responde" (apagado, en el estuche o lejos), que antes se
    // confundían y llevaban a olvidar dispositivos que no tenían nada roto.
    property var connectingAddrs: []   // Direcciones con una conexión lanzada desde aquí y sin respuesta todavía

    function connectDevice(dev) {
        if (!dev || root.connectingAddrs.includes(dev.address)) return   // Ya hay una conexión en marcha para este dispositivo
        const wasDiscovering = root.adapter?.discovering ?? false
        root.connectingAddrs = [...root.connectingAddrs, dev.address]
        root.updateDiscovery()            // Para la búsqueda mientras conecta
        const job = connectJob.createObject(root, { address: dev.address, name: dev.name })
        job.exec(["sh", "-c",
            '[ "$2" = 1 ] && sleep 0.3; '                                               // Margen para que BlueZ pare la búsqueda antes de conectar
            + 'busctl call --timeout=60 org.bluez "$1" org.bluez.Device1 Connect 2>&1; '  // Si falla escribe "Call failed: <motivo>"
            + 'echo "exit|$?"',
            "sh", dev.dbusPath, wasDiscovering ? "1" : "0"])
    }

    // Ha terminado una conexión lanzada desde connectDevice(); output es la salida de busctl
    function connectFinished(address, name, output) {
        root.connectingAddrs = root.connectingAddrs.filter(a => a !== address)
        root.updateDiscovery()            // Vuelve a buscar si el menú sigue abierto
        if (parseInt(Utils.parseLines(output, "exit")[0] ?? "-1") === 0) return   // Conectado
        const reason = output.split("\n").find(l => l.startsWith("Call failed: "))?.slice(13).trim() ?? ""
        const dev = root.deviceByAddress(address)
        if (reason.includes("key-missing")) {
            if (dev && dev.paired) root.flagRepairNeeded(dev)
        } else {
            NotificationCenter.notify("Bluetooth", "", Lang.tr("Bluetooth: no se ha podido conectar"),
                reason.includes("page-timeout") || reason.includes("Host is down")
                    ? Lang.tr("%1 no responde: comprueba que está encendido, fuera del estuche y cerca.", name)
                    : name + ": " + (reason || Lang.tr("error desconocido")))
        }
    }

    // Una conexión en marcha: un Process por cada una, que se destruye al terminar
    Component {
        id: connectJob
        Process {
            id: job
            property string address: ""
            property string name: ""
            stdout: StdioCollector {
                onStreamFinished: {
                    root.connectFinished(job.address, job.name, text)
                    job.destroy()
                }
            }
        }
    }

    // --- Aviso y reparación a mano de los dispositivos que han perdido la clave ---
    // Si al conectar un dispositivo ya emparejado BlueZ responde "br-connection-key-missing",
    // la clave de emparejamiento que guarda el equipo ya no coincide con la del dispositivo
    // (pasa, por ejemplo, al emparejarlo desde otro sistema del mismo ordenador: Windows o
    // Zorin usan el mismo adaptador y su clave nueva pisa a esta). El único arreglo es
    // olvidarlo y volver a emparejarlo, y eso solo funciona si el dispositivo se está
    // anunciando (en modo de emparejamiento) justo en ese momento. Como no se puede saber
    // cuándo lo habrá puesto así el usuario, en vez de reintentar a ciegas en segundo plano
    // se avisa con una notificación y se deja un botón "reparar" en el menú para lanzarlo
    // en el momento justo.
    property var repairNeeded: []      // Direcciones con el botón "reparar" a la vista
    property var repairingAddrs: []    // Direcciones con una reparación en marcha

    function flagRepairNeeded(dev) {
        if (!root.repairNeeded.includes(dev.address))          // Sin repetidos en la lista
            root.repairNeeded = [...root.repairNeeded, dev.address]  // Lista nueva: si se cambia por dentro, QML no se entera
        const m = root.monitorFor(dev)
        const now = Date.now()
        if (now - m.lastNotify < 5 * 60 * 1000) return          // Como mucho un aviso cada 5 min, para no llenar la pantalla de notificaciones
        m.lastNotify = now
        NotificationCenter.notify("Bluetooth", "", Lang.tr("Bluetooth: hay que volver a emparejarlo"),
            Lang.tr("%1 ha perdido la clave de emparejamiento. Ponlo en modo de emparejamiento y pulsa \"reparar\" en el menú de Bluetooth.", dev.name))
    }

    function clearRepairNeeded(address) {
        if (root.repairNeeded.includes(address))
            root.repairNeeded = root.repairNeeded.filter(a => a !== address)  // También lista nueva, por lo mismo
    }

    // Ha cambiado el estado de conexión de un dispositivo
    function stateChanged(dev) {
        if (dev.state === BluetoothDeviceState.Connected) root.clearRepairNeeded(dev.address)  // Se ha arreglado solo (o ya no hace falta avisar)
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
                connectAfterPair.address = dev.address                      // Algunos dispositivos (los mandos de Xbox) se desconectan al acabar de emparejar: hay que conectarlos aparte
                connectAfterPair.restart()
            } else if (m.prevPairing && !dev.pairing) {
                pendingCheck.restart()                                      // El emparejamiento ha terminado sin emparejar... de momento (ver pendingCheck)
            }
        }
        if (dev.paired && root.repairingAddrs.includes(dev.address))
            root.finishRepair(dev.address)                                  // Reparado: connectAfterPair se encarga de conectarlo
        m.prevPairing = dev.pairing
        unbondedCheck.restart()
    }

    // Tras emparejar desde el menú, se espera un momento (a que el dispositivo suelte la
    // conexión del emparejamiento, si la suelta) y se conecta, si no lo está ya. Sin esto el
    // mando se quedaba emparejado pero desconectado, y parecía que el emparejamiento había fallado.
    Timer {
        id: connectAfterPair
        interval: 1500
        property string address: ""
        onTriggered: {
            const dev = root.deviceByAddress(address)
            if (dev && dev.paired && !dev.connected) root.connectDevice(dev)
        }
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
        function onEnabledChanged() {                               // Se enciende la radio
            root.ensurePairable()
            root.updateDiscovery()                                  // Si el menú está abierto, que se ponga a buscar
        }
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
                    NotificationCenter.notify("Bluetooth", "", Lang.tr("Bluetooth: emparejamiento no guardado"),
                        Lang.tr("%1 se ha emparejado sin guardar la clave: al desconectarse se olvidará y no podrá volver a conectarse. Olvídalo y vuelve a emparejarlo desde el menú.", dev.name))
                }
            }
            if (unbondedNow.join() !== root.unbondedAddrs.join())   // Solo si ha cambiado, para no redibujar el menú
                root.unbondedAddrs = unbondedNow
        }
    }

    // --- Reparación ---
    // Se lanza a mano desde el botón "reparar": olvida el dispositivo, busca hasta que vuelve
    // a aparecer (BlueZ lo borra al olvidarlo y tarda unos segundos en volver a verlo) y en
    // cuanto aparece lo empareja (ver deviceAppeared). Solo sale bien si el dispositivo está
    // en modo de emparejamiento; si en repairTimeout no se ha emparejado, se da por fallida.
    function repairDevice(address) {
        if (root.repairingAddrs.includes(address)) return   // Ya hay una reparación en marcha para este dispositivo
        const dev = root.deviceByAddress(address)
        if (!dev) return
        root.repairingAddrs = [...root.repairingAddrs, address]
        root.updateDiscovery()            // Busca para volver a ver el dispositivo tras el forget()
        dev.forget()                      // Borra la clave vieja
        repairTimeout.address = address
        repairTimeout.restart()
    }

    function finishRepair(address) {
        root.repairingAddrs = root.repairingAddrs.filter(a => a !== address)
        root.clearRepairNeeded(address)   // Ya se ha intentado; si vuelve a fallar al conectar, connectFinished() lo volverá a marcar
        root.updateDiscovery()            // Deja la búsqueda como diga el menú
    }

    // Ha aparecido un dispositivo (o todos, al arrancar)
    function deviceAppeared(dev) {
        root.monitorFor(dev)
        unbondedCheck.restart()
        if (root.repairingAddrs.includes(dev.address) && !dev.paired && !dev.pairing)
            root.pairAndTrust(dev)        // Es el que se está reparando, ya olvidado: a emparejarlo de nuevo
    }

    Timer {
        id: repairTimeout
        interval: 30000   // Tiempo que se le da a la reparación (volver a verlo, emparejar y confirmar el código)
        property string address: ""
        onTriggered: {
            if (!root.repairingAddrs.includes(address)) return       // Ya ha terminado bien
            const dev = root.deviceByAddress(address)
            if (dev && dev.pairing) { restart(); return }             // Sigue emparejándose (p.ej. esperando a confirmar el código): más tiempo
            root.finishRepair(address)
            NotificationCenter.notify("Bluetooth", "", Lang.tr("Bluetooth: no se ha podido reparar"),
                Lang.tr("No se ha podido volver a emparejar el dispositivo. Ponlo en modo de emparejamiento y emparéjalo desde el menú de Bluetooth."))
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

            Component.onCompleted: root.deviceAppeared(modelData)   // Dispositivo nuevo (o todos, al arrancar)
            function onStateChanged() { root.stateChanged(modelData) }
            function onPairedChanged() { root.pairingChanged(modelData) }
            function onPairingChanged() { root.pairingChanged(modelData) }
            function onBondedChanged() { unbondedCheck.restart() }
        }
    }
}
