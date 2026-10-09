// Zona de ratón de un icono de la barra: algo más grande que el dibujo, para que sea fácil
// atinar, y con una etiqueta (BarTooltip.qml) al dejar el ratón encima. Al pulsar, la
// etiqueta se quita (y no vuelve hasta salir y entrar otra vez). La usan BarIcon.qml, el
// logo de Reddots.qml, la hora de Clock.qml y los iconos de Tray.qml.
//
// Es un MouseArea: quien la usa pone acceptedButtons, onClicked, onWheel... y, si necesita
// hacer algo al entrar o salir el ratón, su propio onContainsMouseChanged (se ejecutan los
// dos: el de aquí y el suyo).
import Quickshell                   // Para el LazyLoader y PopupWindow
import QtQuick

MouseArea {
    id: root

    property string tooltip: ""         // Vacío = sin etiqueta
    property Item target: parent        // Junto a qué sale la etiqueta
    property PopupWindow popup: null    // Desplegable que abre el icono: mientras está abierto no sale la etiqueta (lo taparía)

    anchors.fill: parent
    anchors.margins: -4                 // Zona de clic algo más grande que el icono
    hoverEnabled: true                  // Para la etiqueta

    onContainsMouseChanged: tooltipLoader.active = containsMouse && tooltip !== ""
    onClicked: tooltipLoader.active = false

    LazyLoader {                        // Solo existe mientras el ratón está encima
        id: tooltipLoader
        active: false
        BarTooltip {
            anchorItem: root.target
            text: root.popup && root.popup.visible ? "" : root.tooltip
            hovered: true
        }
    }
}
