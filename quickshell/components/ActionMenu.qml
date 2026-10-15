// Desplegable de la barra con una lista de acciones: una fila (MenuRow.qml) por opción, que
// al pulsarla cierra el menú y hace lo suyo. Lo usan el menú de apagado (Power.qml) y el del
// logo de Reddots (Reddots.qml). Es un BarPopup: se le da anchorItem y, si hace falta, el
// ancho (implicitWidth), como a cualquier desplegable.
//   actions: [{ icon: 0xF0425, label: "Apagar", tooltip: "…", run: () => … }]
// "icon" es el código del glifo de la Nerd Font y "tooltip" (opcional), qué va a pasar, en
// una etiqueta a la derecha del menú al dejar el ratón encima.
//
// También se maneja con el teclado (sobre todo al abrirlo con Alt + F4, el de apagado):
//   ↑ ↓     elegir una fila (la primera pulsación va a la primera o a la última; dan la vuelta)
//   Intro   hacer lo de la fila elegida
//   Esc     cerrar
// El ratón y las flechas mueven la misma fila elegida ("currentIndex"): al pasar el ratón por
// una fila se elige esa, y nunca hay dos resaltadas a la vez.
import QtQuick
import QtQuick.Layouts

BarPopup {
    id: root

    property var actions: []
    property int currentIndex: -1           // Fila elegida (-1 = ninguna, como al abrirlo)

    // Al abrirse empieza sin ninguna elegida (que una fila resaltada no parezca la opción por
    // defecto) y con el foco del teclado en la lista. El teclado le llega a la ventana con el
    // grab que la cierra al hacer clic fuera (ClickOutsideGrab.qml)
    onVisibleChanged: {
        if (!visible) return
        currentIndex = -1
        list.forceActiveFocus()
    }

    // Mueve la fila elegida "step" filas (-1 arriba, 1 abajo), dando la vuelta al llegar al final
    function move(step) {
        const count = actions.length
        if (count === 0) return
        if (currentIndex < 0) currentIndex = step > 0 ? 0 : count - 1
        else currentIndex = (currentIndex + step + count) % count
    }

    function activate(index) {
        const action = actions[index]
        if (!action) return                 // Intro sin ninguna elegida: no hace nada
        visible = false                     // Antes de la acción: algunas abren otra ventana, que el menú taparía
        action.run()
    }

    // Las filas van en su propia columna para tener un elemento que reciba las teclas (la de
    // BarPopup no es accesible desde aquí). Con la misma separación que esa, así que el menú
    // se ve igual
    ColumnLayout {
        id: list
        Layout.fillWidth: true
        spacing: 4

        Keys.onUpPressed: root.move(-1)
        Keys.onDownPressed: root.move(1)
        Keys.onReturnPressed: root.activate(root.currentIndex)
        Keys.onEnterPressed: root.activate(root.currentIndex)      // El Intro del teclado numérico
        Keys.onEscapePressed: root.visible = false

        Repeater {
            model: root.actions

            delegate: MenuRow {
                required property var modelData
                required property int index
                icon: String.fromCodePoint(modelData.icon)
                text: modelData.label
                tooltip: modelData.tooltip ?? ""
                highlighted: index === root.currentIndex
                onHoveredChanged: if (hovered) root.currentIndex = index
                onClicked: root.activate(index)
            }
        }
    }
}
