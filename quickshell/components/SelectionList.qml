// SelectionList.qml
// Lista con una fila seleccionada: la de los buscadores del Launcher y del portapapeles
// (Clipboard.qml). La selección la mueven las flechas (el InputField con "list") y el ratón
// al pasar de una fila a otra, se marca con un fondo, y al hacer clic en una fila avisa con
// activated(index). Si no hay filas, sale "emptyText".
// Las filas (delegate) solo pintan su contenido: el resaltado y el ratón van aquí, iguales
// para todas, en vez de repetirlos en cada fila.
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

    // Es hijo de la lista, así que va dentro de su contenido: sus coordenadas son las de las
    // filas (indexAt) y se desplaza con ellas. Encima de las filas (z) para recibir el ratón;
    // la rueda no la usa, así que le llega a la lista y sigue haciendo scroll.
    MouseArea {
        property int hoverIndex: -1         // Fila bajo el ratón: solo se selecciona al pasar a otra, no con cada movimiento (si no, al mover un poco el ratón se perdería la elegida con las flechas)
        anchors.fill: parent
        z: 2
        hoverEnabled: true
        onPositionChanged: mouse => {
            const i = root.indexAt(mouse.x, mouse.y)
            if (i >= 0 && i !== hoverIndex) root.currentIndex = i
            hoverIndex = i
        }
        onExited: hoverIndex = -1
        onClicked: mouse => {
            const i = root.indexAt(mouse.x, mouse.y)
            if (i >= 0) root.activated(i)
        }
    }
}
