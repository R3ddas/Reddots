// Icono de engranaje que muestra/oculta el grupo de widgets de configuración
// de la barra (uso del sistema, capturas, brillo, geometría, tema, fondo de pantalla y actualizar Reddots). Este archivo solo guarda
// el estado ("expanded"); quién se oculta lo decide shell.qml, enlazando el
// "visible" de ese grupo a esta propiedad. El estado no se guarda en disco,
// así que la barra siempre arranca con los widgets ocultos.
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    property bool expanded: false       // true = widgets de configuración visibles (siempre arranca plegado)
    property Item controls: null        // Si se indica, este icono es un duplicado: muestra y cambia el estado de ese otro SettingsToggle
    readonly property Item owner: controls ?? root      // Quién guarda de verdad el estado

    // Al desplegar, se miran las actualizaciones pendientes para el contador de Reddots.qml,
    // que está dentro del grupo (Updates.qml no mira por su cuenta). Solo en el que guarda
    // el estado: en la copia "expanded" no cambia nunca
    onExpandedChanged: if (expanded) Updates.refresh()

    BarIcon {
        text: String.fromCodePoint(0xf01d8)                                 // Mismo icono plegado y desplegado: el estado se nota por el color
        // Con el color de acento mientras está desplegado. Plegado, en rojo si hay alguna temperatura
        // alta (SystemMonitor.qml): el icono del chip, que es el que avisa, está dentro del grupo
        color: root.owner.expanded ? Theme.textSelected
             : SystemMonitor.overheating ? SystemMonitor.hotColor
             : Theme.textActive
        tooltip: root.owner.expanded ? "Ocultar los ajustes"
               : "Mostrar los ajustes"                  // Sin las actualizaciones: plegado no se miran (ver Updates.qml) y el número podría estar desfasado
                 + (SystemMonitor.overheating ? "\nTemperatura alta: " + SystemMonitor.warning : "")
        onClicked: root.owner.expanded = !root.owner.expanded               // Muestra/oculta el grupo
    }
}
