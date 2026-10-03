// NotificationActions.qml
// Botones con las acciones de una notificación (notify-send -A si=Sí -A no=No ...), en
// las tarjetas emergentes y en la lista de SystemStats. La acción "default" no sale: es
// la que se lanza al hacer clic en la propia notificación. Si no caben en una fila,
// pasan a la siguiente. Sin acciones no se ve.
import QtQuick
import qs.services

Flow {
    id: root

    property var notification: null
    readonly property var buttonActions: notification ? notification.actions.filter(a => a.identifier !== "default") : []

    visible: buttonActions.length > 0
    spacing: 6

    Repeater {
        model: root.buttonActions
        delegate: Rectangle {
            id: actionButton
            required property var modelData
            implicitWidth: actionText.implicitWidth + 16
            implicitHeight: actionText.implicitHeight + 8
            radius: 6
            color: actionMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: Theme.border

            Text {
                id: actionText
                anchors.centerIn: parent
                text: actionButton.modelData.text
                textFormat: Text.PlainText      // Viene de la app: que no se interprete como HTML
                color: Theme.textActive
                font.pixelSize: 11
            }

            MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: actionButton.modelData.invoke()   // La cierra sola, salvo que la app pida que se quede
            }
        }
    }
}
