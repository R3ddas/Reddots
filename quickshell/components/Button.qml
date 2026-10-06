// Button.qml
// Botón con borde: los −/+ de GeometrySettings.qml, las acciones de las notificaciones
// (NotificationActions.qml) y Cancelar/Autenticar de PolkitDialog.qml. Se resalta con el
// ratón encima y avisa con clicked(). Con "accent" es el botón principal (borde y texto con
// el color de acento); con enabled: false sale apagado y no responde.
// Mide lo que el texto más "padding" a cada lado; quien quiera otro tamaño pone el suyo.
import QtQuick
import qs.services

Rectangle {
    id: root

    property alias text: label.text
    property alias font: label.font
    property bool accent: false
    property color idleColor: "transparent"     // Fondo sin el ratón encima
    property int padding: 8                     // Margen del texto a izquierda y derecha
    readonly property bool hovered: area.containsMouse  // Para quien cambie el color por su cuenta (los botones de LockScreen.qml)
    signal clicked()

    implicitWidth: label.implicitWidth + padding * 2
    implicitHeight: label.implicitHeight + 8
    radius: 6
    color: !enabled ? "transparent" : area.containsMouse ? Theme.surfaceHover : idleColor
    border.width: 1
    border.color: accent && enabled ? Theme.textSelected : Theme.border

    Text {
        id: label
        anchors.centerIn: parent
        textFormat: Text.PlainText              // Puede venir de una app (las acciones de una notificación): que no se interprete como HTML
        color: !root.enabled ? Theme.textDisabled : root.accent ? Theme.textSelected : Theme.textActive
        font.bold: root.accent
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()               // Con enabled: false no llega aquí: el MouseArea se desactiva con su padre
    }
}
