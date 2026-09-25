// BarIcon.qml
// Icono de la barra: un glifo de la Nerd Font con la zona de clic algo más grande
// que el dibujo, para que sea fácil atinar. clicked() trae el evento, para saber
// qué botón se ha pulsado (ver acceptedButtons). Con "tooltip" sale una etiqueta
// al dejar el ratón encima (BarTooltip.qml); vacío = sin etiqueta. Al pulsar se quita.
import Quickshell            // Para el LazyLoader
import QtQuick
import QtQuick.Layouts

Text {
    id: root

    property alias acceptedButtons: mouse.acceptedButtons  // Por defecto solo el izquierdo
    property string tooltip: ""
    signal clicked(var event)

    color: Theme.textActive
    font.pixelSize: 18
    Layout.alignment: Qt.AlignHCenter

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -4                             // Zona de clic algo más grande que el icono
        hoverEnabled: true                              // Para el tooltip
        onClicked: event => {
            tooltipLoader.active = false                // Al pulsar se quita (y no vuelve hasta salir y entrar otra vez)
            root.clicked(event)
        }
        onContainsMouseChanged: tooltipLoader.active = containsMouse && root.tooltip !== ""
    }

    LazyLoader {                                        // Solo existe mientras el ratón está encima
        id: tooltipLoader
        active: false
        BarTooltip {
            anchorItem: root
            text: root.tooltip
            hovered: true
        }
    }
}
