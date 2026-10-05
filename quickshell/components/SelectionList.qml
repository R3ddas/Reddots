// SelectionList.qml
// Lista con una fila seleccionada: la de los buscadores del Launcher y del portapapeles
// (Clipboard.qml). La selección la mueven las flechas (el InputField con "list") y el ratón
// al pasar de una fila a otra, se marca con un fondo, y al hacer clic en una fila avisa con
// activated(index). Si no hay filas, sale "emptyText".
// Las filas (delegate) solo pintan su contenido: el resaltado y el ratón van aquí, iguales
// para todas, en vez de repetirlos en cada fila.
// Si una fila tiene un botón propio (la papelera del Launcher), el clic no le llega: se lo
// queda el MouseArea de aquí, que está encima. Para eso la fila puede tener una función
// handleClick(x, y), en sus coordenadas: si devuelve true es que el clic era para ese botón
// y ya lo ha atendido, y no se avisa con activated().
import QtQuick
import QtQuick.Layouts
import qs.services

ListView {
    id: root

    property string emptyText: "Sin resultados"
    signal activated(int index)

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    spacing: 4
    boundsBehavior: Flickable.StopAtBounds
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)  // Hace scroll para que el seleccionado se vea

    // El fondo de la fila seleccionada: el ratón y las flechas mueven la misma selección
    highlight: Rectangle { radius: 8; color: Theme.surfaceHover }
    highlightMoveDuration: 0                // Sin animación: salta directamente a la fila nueva
    highlightResizeDuration: 0

    Text {
        visible: root.count === 0
        text: root.emptyText
        color: Theme.textDisabled
    }

    // Sobre la parte visible de la lista (parent: root; si no, al declararla aquí dentro iría
    // al contenido, que no mide ni se mueve como se esperaría) y encima de las filas (z) para
    // recibir el ratón. La rueda no la usa, así que le llega a la lista y sigue haciendo scroll.
    // Sus coordenadas son las de la parte visible: para saber qué fila hay debajo se pasan
    // a las del contenido (rowAt), que es lo que pide indexAt. Sin esto, al bajar con la
    // rueda se elegía y se abría una fila de más arriba.
    MouseArea {
        id: area
        property int hoverIndex: -1         // Fila bajo el ratón: solo se selecciona al pasar a otra, no con cada movimiento (si no, al mover un poco el ratón se perdería la elegida con las flechas)
        property point lastPos: Qt.point(0, 0)

        function rowAt(x, y) {
            const p = root.contentItem.mapFromItem(area, x, y)
            return root.indexAt(p.x, p.y)
        }

        // Pasa a la fila que hay en (x, y), si es otra que la de antes
        function hoverAt(x, y) {
            lastPos = Qt.point(x, y)
            const i = rowAt(x, y)
            if (i >= 0 && i !== hoverIndex) root.currentIndex = i
            hoverIndex = i
        }

        parent: root
        anchors.fill: parent
        z: 2
        hoverEnabled: true
        onPositionChanged: mouse => hoverAt(mouse.x, mouse.y)
        onExited: hoverIndex = -1
        onClicked: mouse => {
            const i = rowAt(mouse.x, mouse.y)
            if (i < 0) return
            const row = root.itemAtIndex(i)
            const p = row.mapFromItem(area, mouse.x, mouse.y)
            if (!(row.handleClick && row.handleClick(p.x, p.y))) root.activated(i)
        }
    }

    // Al hacer scroll con la rueda el ratón no se mueve, pero cambia la fila que tiene debajo:
    // se selecciona esa, como si se hubiera movido hasta ella
    onContentYChanged: if (area.containsMouse) area.hoverAt(area.lastPos.x, area.lastPos.y)
}
