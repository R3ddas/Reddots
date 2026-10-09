// Fondo con el estilo de los desplegables de la barra: color "surface", borde con el color
// de acento y redondeo y grosor del borde editables en GeometrySettings.qml. Lo usan
// BarPopup.qml y las ventanas sueltas (Osd, Keybinds, Clipboard, Launcher, PolkitDialog),
// así el estilo se cambia en un solo sitio.
import QtQuick
import qs.services

Rectangle {
    color: Theme.surface
    radius: Geometry.popupRounding
    border.color: Theme.textSelected
    border.width: Geometry.popupBorderWidth
}
