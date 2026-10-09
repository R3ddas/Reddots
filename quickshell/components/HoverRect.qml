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
    signal clicked(var mouse)

    radius: 4
    color: hovered ? Theme.surfaceHover : idleColor

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: mouse => root.clicked(mouse)
    }
}
