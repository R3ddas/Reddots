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

    BarIcon {
        text: String.fromCodePoint(0xf01d8)                                 // Mismo icono plegado y desplegado: el estado se nota por el color
        // Con el color de acento mientras está desplegado. Plegado, en rojo si hay alguna temperatura
        // alta (SystemMonitor.qml): el icono del chip, que es el que avisa, está dentro del grupo
        color: root.owner.expanded ? Theme.textSelected
             : SystemMonitor.overheating ? SystemMonitor.hotColor
             : Theme.textActive
        tooltip: root.owner.expanded ? "Ocultar los ajustes"
               : "Mostrar los ajustes" + (Updates.count > 0 ? "\n" + Updates.summary : "")
                 + (SystemMonitor.overheating ? "\nTemperatura alta: " + SystemMonitor.warning : "")
        onClicked: root.owner.expanded = !root.owner.expanded               // Muestra/oculta el grupo
    }

    Text {                  // Actualizaciones pendientes: con el grupo plegado no se ve el icono de Reddots, así que el número sale aquí
        visible: root.controls === null && !root.expanded && Updates.count > 0
        text: Updates.count > 99 ? "99+" : Updates.count
        color: Theme.textSelected
        font.pixelSize: 10
        font.bold: true
        Layout.alignment: Qt.AlignHCenter
    }
}
