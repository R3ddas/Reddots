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
        delegate: Button {
            required property var modelData
            text: modelData.text                    // Viene de la app: Button lo pinta como texto plano
            font.pixelSize: 11
            idleColor: Theme.surface
            onClicked: modelData.invoke()           // La cierra sola, salvo que la app pida que se quede
        }
    }
}
