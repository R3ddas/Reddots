// Desplegable de la barra: sale a la derecha de la barra, a la altura del icono que
// lo abre ("anchorItem"), con el fondo, el borde y el redondeo del tema, y se cierra
// al hacer clic fuera. Lo usan todos los iconos de la barra que abren un menú.
//
// Lo que se pone dentro va en una columna (ColumnLayout) sobre el fondo con borde, a
// "padding" px del borde, y el popup mide lo que mida esa columna. Quien lo usa solo
// tiene que darle anchorItem y, si no quiere que se ajuste al contenido, el ancho
// (implicitWidth). Lo de dentro que tenga que ocupar todo el ancho, con Layout.fillWidth.
// Si necesita hacer algo al abrirse o cerrarse, puede poner su propio onVisibleChanged.
//
// Hay dos estilos, según Geometry.popupAttached (se elige en GeometrySettings.qml):
//   - Suelto: separado de la barra, con Frame.qml (fondo "surface", borde de acento y redondeo).
//   - Unido: pegado al borde interior del marco de la pantalla (Border.qml), del color de la
//     barra y sin borde de color, así que parece que sale de ella. Donde se junta con el marco
//     hace dos curvas hacia dentro ("orejas", arriba y abajo), del tamaño del redondeo, y las
//     esquinas de la derecha van redondeadas como siempre. La ventana es más alta que el
//     contenido para que quepan las orejas (attachedEar px por arriba y por abajo).
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

    readonly property bool attached: Geometry.popupAttached
    readonly property int attachedEar: attached ? Geometry.popupRounding : 0   // Alto de cada oreja del estilo unido

    // Mínimo 40 de alto: un menú que se queda vacío un momento (sin dispositivos, buscando...) no queda como una raya
    implicitWidth: column.implicitWidth + padding * 2
    implicitHeight: Math.max(40, column.implicitHeight + padding * 2) + attachedEar * 2

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

    // Dónde está el icono dentro de la barra (x). anchor.rect es relativo al icono, así que el estilo
    // unido lo necesita para empezar justo en el borde interior del marco. mapToItem no avisa
    // cuando el icono se mueve, así que se apunta al colocarlo (en onAnchoring)
    property real anchorItemX: 0

    anchor.item: anchorItem
    // Suelto: que el menú no tape la barra, aparece a partir de su borde derecho (más lo que el icono
    // esté separado del borde izquierdo de la barra). Unido: pegado al borde interior del marco
    anchor.rect.x: attached ? Geometry.sidebarWidth + Geometry.borderThickness - anchorItemX : Geometry.sidebarWidth
    anchor.gravity: Edges.Bottom | Edges.Right      // Sin "Right" el popup se centra en el punto de anclaje y vuelve a tapar la barra
    // A la altura del icono; si no cabe, se mueve lo justo para dejar el mismo hueco que a la izquierda
    // (unido no hay hueco: llega hasta el marco de arriba o de abajo). Ya abierto, se intenta dejar
    // donde estaba (ver placedY)
    anchor.onAnchoring: {
        if (!anchorItem) return
        anchorItemX = anchorItem.mapToItem(null, 0, 0).x      // Antes que la y: popupY usa anchor.rect.x, que depende de esto
        anchor.rect.y = Geometry.popupY(anchorItem, anchor.rect.x, implicitHeight, isNaN(placedY) ? undefined : placedY)
        if (visible) placedY = anchor.rect.y
    }

    // Fondo suelto
    Frame {
        anchors.fill: parent
        visible: !root.attached
    }

    // Fondo unido (el mismo que las etiquetas de la barra, BarTooltip.qml)
    AttachedBackground {
        anchors.fill: parent
        visible: root.attached
        ear: root.attachedEar
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: root.padding
        anchors.topMargin: root.padding + root.attachedEar      // Unido, lo de dentro no se mete en las orejas
        anchors.bottomMargin: root.padding + root.attachedEar
        spacing: 4
    }

    ClickOutsideGrab { window: root }                   // Se cierra al hacer clic fuera
}
