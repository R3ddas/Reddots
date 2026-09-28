// BarPopup.qml
// Desplegable de la barra: sale a la derecha de la barra, a la altura del icono que
// lo abre ("anchorItem"), con el fondo, el borde y el redondeo del tema, y se cierra
// al hacer clic fuera. Lo usan todos los iconos de la barra que abren un menú.
//
// Lo que se pone dentro va sobre el fondo con borde (cada uno pone sus márgenes).
// Quien lo usa solo tiene que darle anchorItem y el tamaño (implicitWidth/Height);
// si necesita hacer algo al abrirse o cerrarse, puede poner su propio onVisibleChanged
// (se ejecutan los dos: el de aquí y el suyo).
import Quickshell
import Quickshell.Hyprland          // Para el HyprlandFocusGrab
import QtQuick

PopupWindow {
    id: root
    visible: false
    color: "transparent"

    property Item anchorItem: null                  // Icono de la barra junto al que sale
    default property alias content: frame.data     // Lo de dentro va sobre el fondo con borde

    function toggle() { visible = !visible }

    anchor.item: anchorItem
    anchor.rect.x: Geometry.sidebarWidth            // Que el menú no tape la barra, aparece a partir de su borde derecho
    anchor.gravity: Edges.Bottom | Edges.Right      // Sin "Right" el popup se centra en el punto de anclaje y vuelve a tapar la barra
    anchor.onAnchoring: if (anchorItem) anchor.rect.y = Geometry.popupY(anchorItem, anchor.rect.x, implicitHeight)  // A la altura del icono; si no cabe, se mueve lo justo para dejar el mismo hueco que a la izquierda

    onVisibleChanged: {
        if (visible) grabTimer.restart()
        else { grabTimer.stop(); grab.active = false }
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        color: Theme.surface
        radius: Geometry.popupRounding                  // Redondeo propio de los desplegables (editable en GeometrySettings)
        border.color: Theme.textSelected                // Borde con el color de acento del tema
        border.width: Geometry.popupBorderWidth         // Grosor editable en GeometrySettings
    }

    HyprlandFocusGrab {                                 // Cierra el popup al hacer clic fuera de él
        id: grab
        windows: [root]
        active: false
        onCleared: root.visible = false
    }

    Timer {
        id: grabTimer
        interval: 5                                     // Deja que el popup termine de abrirse antes de activar el grab (si no, lo cierra el mismo clic que lo abrió)
        onTriggered: grab.active = true
    }
}
