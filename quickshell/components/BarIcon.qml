// Icono de la barra: un glifo de la Nerd Font con la zona de clic algo más grande
// que el dibujo, para que sea fácil atinar. clicked() trae el evento, para saber
// qué botón se ha pulsado (ver acceptedButtons). Con "tooltip" sale una etiqueta
// al dejar el ratón encima (TooltipArea.qml); vacío = sin etiqueta. Al pulsar se quita.
//
// Con "popup" (el BarPopup que abre el icono), el clic izquierdo lo abre y lo cierra solo
// y la etiqueta no sale mientras está abierto: quien lo usa solo tiene que ocuparse de los
// demás botones (p.ej. el derecho para silenciar en Volume.qml).
import Quickshell                   // Para PopupWindow
import QtQuick
import QtQuick.Layouts
import qs.services

Text {
    id: root

    property alias acceptedButtons: area.acceptedButtons  // Por defecto solo el izquierdo
    property string tooltip: ""
    property PopupWindow popup: null
    signal clicked(var event)

    color: Theme.textActive
    font.pixelSize: 18
    Layout.alignment: Qt.AlignHCenter

    TooltipArea {
        id: area
        tooltip: root.tooltip
        popup: root.popup
        onClicked: event => {
            if (root.popup && event.button === Qt.LeftButton) root.popup.toggle()
            root.clicked(event)
        }
    }
}
