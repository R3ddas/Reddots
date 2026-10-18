// Un grupo de iconos de la barra (Bar.qml): una columna centrada y de ancho fijo.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    spacing: 5
    Layout.alignment: Qt.AlignHCenter       // Sin esto el grupo queda pegado a la izquierda (es más estrecho que la barra) y sus iconos se descentran
    // Ancho fijo (el del layout padre), para que un icono más ancho/estrecho (p.ej. el de wifi al cambiar de estado) no desplace a todos los demás al recalcular el ancho del grupo
    Layout.fillWidth: true
    // Sin esto fillWidth no hace nada: el máximo de un layout es el ancho de su hijo más ancho (los hijos sin fillWidth no crecen), así que el grupo seguía midiendo lo que su icono más ancho y al cambiar este se movía todo 1 px por redondeo
    Layout.maximumWidth: Infinity
}
