// Columna para listas largas dentro de un desplegable: crece con lo que lleva dentro hasta
// "maxHeight" y, a partir de ahí, se recorta y se mueve con la rueda (sin rebote al llegar
// arriba o abajo). La usan los temas (ThemeSettings.qml), los fondos (WallpaperSettings.qml)
// y las notificaciones del popup de SystemStats.qml. Lo de dentro va en una columna
// (ColumnLayout), como en BarPopup.qml: lo que tenga que ocupar todo el ancho, con
// Layout.fillWidth.
import QtQuick
import QtQuick.Layouts

Flickable {
    id: root

    property real maxHeight: 400                    // Alto a partir del cual se hace scroll
    default property alias content: column.data     // Lo de dentro va en la columna
    property alias spacing: column.spacing

    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(maxHeight, column.implicitHeight)
    clip: true                                      // Oculta lo que queda fuera
    contentWidth: width
    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    // Desplaza lo justo para que "item" (algo de dentro) se vea entero: para seguir con el
    // teclado una fila elegida con las flechas (ThemeSettings.qml). Si ya se ve, no se mueve
    function ensureVisible(item) {
        const y = item.mapToItem(column, 0, 0).y            // La columna empieza en lo alto del contenido
        if (y < contentY) contentY = y
        else if (y + item.height > contentY + height) contentY = y + item.height - height
    }

    ColumnLayout {
        id: column
        width: root.width
    }
}
