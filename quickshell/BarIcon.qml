// BarIcon.qml
// Icono de la barra: un glifo de la Nerd Font con la zona de clic algo más grande
// que el dibujo, para que sea fácil atinar. clicked() trae el evento, para saber
// qué botón se ha pulsado (ver acceptedButtons).
import QtQuick
import QtQuick.Layouts

Text {
    id: root

    property alias acceptedButtons: mouse.acceptedButtons  // Por defecto solo el izquierdo
    signal clicked(var event)

    color: Theme.textActive
    font.pixelSize: 18
    Layout.alignment: Qt.AlignHCenter

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -4                             // Zona de clic algo más grande que el icono
        onClicked: event => root.clicked(event)
    }
}
