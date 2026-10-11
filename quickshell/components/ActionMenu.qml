// Desplegable de la barra con una lista de acciones: una fila (MenuRow.qml) por opción, que
// al pulsarla cierra el menú y hace lo suyo. Lo usan el menú de apagado (Power.qml) y el del
// logo de Reddots (Reddots.qml). Es un BarPopup: se le da anchorItem y, si hace falta, el
// ancho (implicitWidth), como a cualquier desplegable.
//   actions: [{ icon: 0xF0425, label: "Apagar", tooltip: "…", run: () => … }]
// "icon" es el código del glifo de la Nerd Font y "tooltip" (opcional), qué va a pasar, en
// una etiqueta a la derecha del menú al dejar el ratón encima.
import QtQuick

BarPopup {
    id: root

    property var actions: []

    Repeater {
        model: root.actions

        delegate: MenuRow {
            required property var modelData
            icon: String.fromCodePoint(modelData.icon)
            text: modelData.label
            tooltip: modelData.tooltip ?? ""
            onClicked: {
                root.visible = false        // Antes de la acción: algunas abren otra ventana, que el menú taparía
                modelData.run()
            }
        }
    }
}
