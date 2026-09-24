// Icono de engranaje que muestra/oculta el grupo de widgets de configuración
// de la barra (geometría, tema y fondo de pantalla). Este archivo solo guarda
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

    Text {
        text: String.fromCodePoint(root.expanded ? 0xf01d8 : 0xf01d8)      // cog (desplegado) / cog-outline (plegado)
        color: root.expanded ? Theme.textSelected : Theme.textActive       // Con el color de acento mientras está desplegado
        font.pixelSize: 18
        Layout.alignment: Qt.AlignHCenter

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4                             // Zona de clic algo más grande que el icono
            onClicked: root.expanded = !root.expanded       // Muestra/oculta el grupo
        }
    }
}
