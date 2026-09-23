// Icono de engranaje que muestra/oculta el grupo de widgets de configuración
// de la barra (geometría, tema y fondo de pantalla). Este archivo solo guarda
// el estado ("expanded"); quién se oculta lo decide shell.qml, enlazando el
// "visible" de ese grupo a esta propiedad. El estado se guarda en disco, así
// que la barra arranca como se dejó la última vez.
import Quickshell
import Quickshell.Io                // Para FileView y JsonAdapter
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    property alias expanded: adapter.expanded   // true = widgets de configuración visibles

    Text {
        text: String.fromCodePoint(root.expanded ? 0xF0493 : 0xF08BB)      // cog (desplegado) / cog-outline (plegado)
        color: root.expanded ? Theme.textSelected : Theme.textActive       // Con el color de acento mientras está desplegado
        font.pixelSize: 18
        Layout.alignment: Qt.AlignHCenter

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4                             // Zona de clic algo más grande que el icono
            onClicked: root.expanded = !root.expanded       // Muestra/oculta el grupo
        }
    }

    FileView {
        path: Quickshell.statePath("settingsToggle.json")  // Fuera del repo, junto a theme.json y geometry.json
        watchChanges: true
        onFileChanged: reload()                             // Si se edita el JSON a mano, se recarga solo
        onAdapterUpdated: writeAdapter()                    // Guarda el estado cada vez que se pulsa el icono

        JsonAdapter {
            id: adapter
            property bool expanded: false                   // Solo si aún no existe settingsToggle.json: arranca plegado
        }
    }
}
