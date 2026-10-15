// Rectángulo que se resalta con el ratón encima (el color "surfaceHover" del tema) y avisa con
// clicked() al pulsarlo: las filas de los menús de wifi (Network.qml) y Bluetooth
// (Bluetooths.qml), los temas del selector (ThemeSettings.qml), las miniaturas de los fondos
// (WallpaperSettings.qml) y el "+N más" de las notificaciones (Notifications.qml).
// Lo de dentro se pone como en un Rectangle y queda por encima de la zona de clic: lo que
// tenga la suya (un TextButton, como "reparar" en Bluetooth) se queda con sus clics.
import QtQuick
import qs.services

Rectangle {
    id: root

    property color idleColor: "transparent"                 // Fondo sin el ratón encima
    property alias acceptedButtons: area.acceptedButtons    // Por defecto solo el izquierdo
    readonly property bool hovered: area.containsMouse
    // Con el fondo resaltado: por defecto, con el ratón encima. Las listas que se manejan también
    // con el teclado (los temas de ThemeSettings.qml) dicen ellas qué fila se resalta, para que
    // el ratón y las flechas no resalten dos a la vez (como MenuRow.qml en ActionMenu.qml)
    property bool highlighted: hovered
    signal clicked(var mouse)

    radius: 4
    color: highlighted ? Theme.surfaceHover : idleColor

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: mouse => root.clicked(mouse)
    }
}
