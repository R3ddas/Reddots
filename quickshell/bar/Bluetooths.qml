// Icono de Bluetooth en la barra: apagado, encendido o con algo conectado.
//   Clic izquierdo: menú con los dispositivos (busca mientras está abierto). Pulsar uno
//   lo conecta o desconecta, empareja uno nuevo o cancela un emparejamiento en curso;
//   "reparar" sale en los que han perdido la clave
//   Clic derecho: enciende/apaga la radio
// El estado y los avisos los lleva services/BluetoothMonitor.qml; aquí solo se pinta.
import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 6

    readonly property var adapter: BluetoothMonitor.adapter               // null si el equipo no tiene Bluetooth
    readonly property bool powered: BluetoothMonitor.powered              // radio encendida/apagada
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

    // El estado de los dispositivos (reparaciones, emparejamientos pendientes, avisos) está
    // en services/BluetoothMonitor.qml, que no se destruye con la barra. Aquí solo se pinta.
    Binding {                           // Para que, tras una reparación, el escaneo quede como diga el menú
        target: BluetoothMonitor
        property: "menuOpen"
        value: menu.visible
    }

    BarIcon {
        id: iconText
        text: root.icon
        color: root.powered ? Theme.textActive : Theme.textDisabled
        tooltip: !root.adapter ? "Sin Bluetooth"
               : !root.powered ? "Bluetooth apagado"
               : !root.active ? "Bluetooth: nada conectado"
               : root.active.name + (root.active.batteryAvailable ? " · batería " + Math.round(root.active.battery * 100) + " %" : "")
        popup: menu                                                                     // clic izq: abre/cierra el menú de dispositivos
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton && root.adapter) root.adapter.enabled = !root.adapter.enabled   // clic der: enciende/apaga el radio Bluetooth
        }
    }

    BarPopup {
        id: menu
        anchorItem: iconText
        implicitWidth: 240

        // Escanea mientras el menú está abierto; se detiene al cerrarlo para no gastar batería
        onVisibleChanged: if (root.adapter) root.adapter.discovering = visible

        Text {
            Layout.fillWidth: true
            visible: root.visibleDevices.length === 0   // placeholder solo cuando la lista filtrada está vacía
            text: root.powered ? (root.adapter?.discovering ? "Buscando…" : "Sin dispositivos") : "Bluetooth apagado"
            color: Theme.textDisabled
        }

        Text {
            Layout.fillWidth: true
            visible: BluetoothMonitor.unbondedAddrs.length > 0   // solo si hay algún emparejamiento sin clave guardada
            text: String.fromCodePoint(0xF0026) + " Hay dispositivos emparejados sin clave guardada: olvídalos y vuelve a emparejarlos"
            wrapMode: Text.WordWrap
            color: Theme.error
        }

        Repeater {
            model: root.visibleDevices   // lista ya filtrada, no el modelo crudo del adaptador

            delegate: Rectangle {
                id: deviceRow
                required property var modelData
                readonly property bool needsRepair: BluetoothMonitor.repairNeeded.includes(modelData.address)   // muestra el botón "reparar"
                readonly property bool repairing: BluetoothMonitor.repairingAddrs.includes(modelData.address)   // reparación en curso -> deshabilita el botón

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
                        const icon = modelData.connected ? 0xF00B1  // bluetooth-connect: conectado
                            : modelData.pairing ? 0xF051F           // timer-sand: emparejando (antes un emoji ⏳)
                            : modelData.paired ? 0xF00AF            // bluetooth: emparejado pero desconectado
                            : 0xF00B2                               // bluetooth-off: dispositivo nuevo, sin emparejar
                        const suffix = modelData.paired ? "" : "  (nuevo)"
                        return String.fromCodePoint(icon) + "  " + modelData.name + suffix
                    }
                    color: modelData.connected ? Theme.textActive : Theme.textDisabled
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: deviceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (modelData.pairing) modelData.cancelPair()           // clic durante el pairing = cancelarlo
                        else if (modelData.connected) modelData.disconnect()
                        else if (modelData.paired) modelData.connect()          // ya conocido: solo reconectar
                        else BluetoothMonitor.pairAndTrust(modelData)           // desconocido: emparejar por primera vez (y marcar de confianza)
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
                        onClicked: BluetoothMonitor.repairDevice(modelData.address)
                    }
                }
            }
        }
    }
}
