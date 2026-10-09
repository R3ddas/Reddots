// Título de una sección con una línea debajo, en el color de acento: los grupos de
// GeometrySettings.qml, Claros/Oscuros en ThemeSettings.qml y las secciones de la chuleta
// de atajos (Keybinds.qml). El tamaño de letra lo pone quien lo usa (font.pixelSize):
// la chuleta usa el normal y los desplegables uno más pequeño.
import QtQuick
import QtQuick.Layouts
import qs.services

ColumnLayout {
    id: root

    property alias text: label.text
    property alias font: label.font
    property int indent: 0              // Sangría del texto (la línea va siempre de lado a lado)

    Layout.fillWidth: true

    Text {
        id: label
        Layout.leftMargin: root.indent
        color: Theme.textSelected
        font.bold: true
    }

    Separator {}
}
