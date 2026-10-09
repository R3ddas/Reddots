// Desplegable de la barra: sale a la derecha de la barra, a la altura del icono que
// lo abre ("anchorItem"), con el fondo, el borde y el redondeo del tema, y se cierra
// al hacer clic fuera. Lo usan todos los iconos de la barra que abren un menú.
//
// Lo que se pone dentro va en una columna (ColumnLayout) sobre el fondo con borde, a
// "padding" px del borde, y el popup mide lo que mida esa columna. Quien lo usa solo
// tiene que darle anchorItem y, si no quiere que se ajuste al contenido, el ancho
// (implicitWidth). Lo de dentro que tenga que ocupar todo el ancho, con Layout.fillWidth.
// Si necesita hacer algo al abrirse o cerrarse, puede poner su propio onVisibleChanged.
import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.services

PopupWindow {
    id: root
    visible: false
    color: "transparent"

    property Item anchorItem: null                  // Icono de la barra junto al que sale
    default property alias content: column.data    // Lo de dentro va en la columna, sobre el fondo con borde
    property alias spacing: column.spacing          // Separación entre lo de dentro
    property int padding: 8                         // Margen entre el borde y lo de dentro
    readonly property alias contentWidth: column.implicitWidth   // Lo que pide lo de dentro (para un ancho que se ajuste con límites, como en Tray.qml)

    // Mínimo 40 de alto: un menú que se queda vacío un momento (sin dispositivos, buscando...) no queda como una raya
    implicitWidth: column.implicitWidth + padding * 2
    implicitHeight: Math.max(40, column.implicitHeight + padding * 2)

    function toggle() { visible = !visible }

    // Posición (anchor.rect.y) en la que se ha colocado al abrirse; NaN mientras está cerrado.
    //
    // Quickshell vuelve a colocar el popup (y llama a anchor.onAnchoring) cada vez que cambia
    // de alto, y popupY lo recentraba con el icono: con el popup abierto, cualquier cambio de
    // contenido (el brillo al terminar de buscar pantallas, la lista de redes o de Bluetooth...)
    // lo movía. Hyprland, al mover un popup, a veces no repinta donde estaba, y dejaba ahí una
    // imagen fija del popup (arriba, porque al crecer sube) hasta que se cerraba. Así que, una vez
    // abierto, se queda con el borde de arriba donde estaba y crece o encoge por abajo; solo se
    // mueve, lo justo, si así ya no cabe en la pantalla.
    property real placedY: NaN
    onVisibleChanged: if (!visible) placedY = NaN   // La próxima vez que se abra, se centra otra vez con el icono

    anchor.item: anchorItem
    anchor.rect.x: Geometry.sidebarWidth            // Que el menú no tape la barra, aparece a partir de su borde derecho
    anchor.gravity: Edges.Bottom | Edges.Right      // Sin "Right" el popup se centra en el punto de anclaje y vuelve a tapar la barra
    // A la altura del icono; si no cabe, se mueve lo justo para dejar el mismo hueco que a la izquierda.
    // Ya abierto, se intenta dejar donde estaba (ver placedY)
    anchor.onAnchoring: {
        if (!anchorItem) return
        anchor.rect.y = Geometry.popupY(anchorItem, anchor.rect.x, implicitHeight, isNaN(placedY) ? undefined : placedY)
        if (visible) placedY = anchor.rect.y
    }

    Frame {
        anchors.fill: parent

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: root.padding
            spacing: 4
        }
    }

    ClickOutsideGrab { window: root }                   // Se cierra al hacer clic fuera
}
