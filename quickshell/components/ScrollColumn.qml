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

    ColumnLayout {
        id: column
        width: root.width
    }
}
