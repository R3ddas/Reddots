// TextButton.qml
// Texto que se pulsa: las flechas del calendario, "Conectar" del wifi, "reparar" del
// Bluetooth, la ✕ y los enlaces de las notificaciones, los controles de reproducción...
// La zona de clic es algo más grande que el texto, para que sea fácil atinar, y avisa con
// clicked(). Con "hovered" quien lo usa puede cambiar el color al pasar el ratón; con
// enabled: false deja de responder (el aspecto lo decide quien lo usa).
import QtQuick
import qs.services

Text {
    id: root

    readonly property bool hovered: area.containsMouse
    signal clicked()

    color: Theme.textActive

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4                 // Zona de clic algo más grande que el texto
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
