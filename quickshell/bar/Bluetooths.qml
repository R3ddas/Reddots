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
    readonly property bool powered: BluetoothMonitor.powered              // Radio encendida o apagada
    readonly property var active: adapter                                 // Primer dispositivo conectado (para el icono)
        ? adapter.devices.values.find(d => d.connected) ?? null
        : null

    // Sin los dispositivos anónimos (los que no anuncian nombre: BlueZ les pone de
    // "nombre" su propia MAC, pero con guiones en vez de dos puntos, así que no basta con
    // compararlo con la dirección tal cual), para no llenar el menú de balizas BLE ajenas.
    // Los ya emparejados salen siempre, aunque no tengan nombre.
    readonly property var macNamePattern: /^[0-9A-Fa-f]{2}(-[0-9A-Fa-f]{2}){5}$/  // "AA-BB-CC-DD-EE-FF"
    readonly property var visibleDevices: adapter
        ? adapter.devices.values.filter(d => d.paired || (d.name && !root.macNamePattern.test(d.name)))  // Emparejados siempre; el resto, solo con nombre de verdad
        : []

    readonly property string icon: {
        if (!powered) return String.fromCodePoint(0xF00B2)  // bluetooth-off
        if (!active)  return String.fromCodePoint(0xF00AF)  // bluetooth
        return String.fromCodePoint(0xF00B1)                // bluetooth-connect
    }

    // El estado de los dispositivos (reparaciones, emparejamientos pendientes, avisos) está
    // en services/BluetoothMonitor.qml, que no se destruye con la barra. Aquí solo se pinta.
    Binding {                           // Para que, tras una reparación, la búsqueda quede como diga el menú
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
        popup: menu                                                                     // Clic izquierdo: abre o cierra el menú de dispositivos
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton && root.adapter) root.adapter.enabled = !root.adapter.enabled   // Clic derecho: enciende o apaga la radio
        }
    }

    BarPopup {
        id: menu
        anchorItem: iconText
        implicitWidth: 240

        // Busca dispositivos mientras el menú está abierto; al cerrarlo para, para no gastar batería
        onVisibleChanged: if (root.adapter) root.adapter.discovering = visible

        Text {
            Layout.fillWidth: true
            visible: root.visibleDevices.length === 0   // Solo si no queda ninguno en la lista (ya filtrada)
            text: root.powered ? (root.adapter?.discovering ? "Buscando…" : "Sin dispositivos") : "Bluetooth apagado"
            color: Theme.textDisabled
        }

        Text {
            Layout.fillWidth: true
            visible: BluetoothMonitor.unbondedAddrs.length > 0   // Solo si hay algún emparejamiento sin clave guardada
            text: String.fromCodePoint(0xF0026) + " Hay dispositivos emparejados sin clave guardada: olvídalos y vuelve a emparejarlos"
            wrapMode: Text.WordWrap
            color: Theme.error
        }

        Repeater {
            model: root.visibleDevices   // La lista ya filtrada, no todos los del adaptador

            delegate: Rectangle {
                id: deviceRow
                required property var modelData
                readonly property bool needsRepair: BluetoothMonitor.repairNeeded.includes(modelData.address)   // Enseña el botón "reparar"
                readonly property bool repairing: BluetoothMonitor.repairingAddrs.includes(modelData.address)   // Reparación en marcha: el botón no responde

                Layout.fillWidth: true
                implicitHeight: 26
                radius: 4
                color: deviceMouse.containsMouse ? Theme.surfaceHover : "transparent"

                Text {
                    id: deviceLabel
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 12 - (deviceRow.needsRepair || deviceRow.repairing ? repairLabel.width + 6 : 0)  // Deja hueco al botón "reparar" si se ve
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
                        if (modelData.pairing) modelData.cancelPair()           // Clic mientras se empareja: lo cancela
                        else if (modelData.connected) modelData.disconnect()
                        else if (modelData.paired) modelData.connect()          // Ya conocido: solo volver a conectar
                        else BluetoothMonitor.pairAndTrust(modelData)           // Nuevo: emparejarlo por primera vez (y marcarlo de confianza)
                    }
                }

                TextButton {
                    id: repairLabel
                    visible: deviceRow.needsRepair || deviceRow.repairing   // Solo sale cuando hace falta
                    enabled: !deviceRow.repairing          // Que no se lance otra reparación mientras ya hay una en marcha
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    text: deviceRow.repairing ? "reparando…" : "reparar"
                    font.underline: !deviceRow.repairing   // Subrayado: se puede pulsar; sin subrayar mientras repara
                    onClicked: BluetoothMonitor.repairDevice(modelData.address)
                }
            }
        }
    }
}
