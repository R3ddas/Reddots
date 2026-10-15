// Fila de un menú de la barra (Power, Screenshot, Reddots, Tray, Volume): icono, texto y,
// si hace falta, una flecha de submenú y una explicación al dejar el ratón encima
// ("tooltip"). Resalta con el ratón encima y avisa con clicked(). En los menús que se
// manejan también con el teclado (ActionMenu.qml) es el menú quien dice qué fila se resalta
// ("highlighted"), para que el ratón y las flechas no resalten dos filas a la vez.
import Quickshell
import Quickshell.Widgets           // Para el IconImage
import QtQuick
import QtQuick.Layouts
import qs.services

Rectangle {
    id: row

    property string icon: ""            // Glifo de la Nerd Font (o "✓", "‹"...); se ignora si hay iconSource
    property string iconSource: ""      // Icono como imagen (los de los menús de la bandeja)
    property string text: ""
    property string tooltip: ""         // Qué va a pasar, en una etiqueta (BarTooltip.qml) a la derecha del menú al dejar el ratón encima
    property bool arrow: false          // Tiene submenú: flecha a la derecha
    property bool active: true          // false = en gris y sin reaccionar al ratón
    property bool selected: false       // La opción en uso (la salida de audio de Volume.qml...): icono y texto con el color de acento
    property bool highlighted: hovered  // Con el fondo resaltado (y su etiqueta, si tiene): por defecto, con el ratón encima
    readonly property bool hovered: rowMouse.containsMouse
    signal clicked()

    Layout.fillWidth: true
    implicitWidth: label.implicitWidth + 28 + 16 + (arrow ? 20 : 0)    // Lo que pide el texto: para los menús que se ajustan a él (Tray)
    implicitHeight: 28
    radius: 4
    color: highlighted && active ? Theme.surfaceHover : "transparent"
    onHighlightedChanged: tooltipLoader.active = highlighted && tooltip !== ""     // También al llegar con las flechas

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 2

        Item {                                          // Icono + texto (+ flecha)
            Layout.fillWidth: true
            implicitHeight: 18

            Text {
                visible: row.iconSource === ""
                text: row.icon
                color: !row.active ? Theme.textDisabled : row.selected ? Theme.textSelected : Theme.textActive
                font.pixelSize: 15
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
            IconImage {
                visible: row.iconSource !== ""
                source: row.iconSource
                implicitSize: 16
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: label
                text: row.text
                color: !row.active ? Theme.textDisabled : row.selected ? Theme.textSelected : Theme.textActive
                elide: Text.ElideRight
                anchors.left: parent.left
                anchors.leftMargin: 28
                anchors.right: arrowText.visible ? arrowText.left : parent.right
                anchors.rightMargin: arrowText.visible ? 8 : 0
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: arrowText
                visible: row.arrow
                text: "›"
                color: Theme.textActive
                font.pixelSize: 14
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: row.active
        onClicked: {
            tooltipLoader.active = false        // Como en TooltipArea.qml: al pulsar se quita (y el menú suele cerrarse)
            row.clicked()
        }
    }

    LazyLoader {                                // Solo existe mientras la fila está resaltada
        id: tooltipLoader
        active: false
        BarTooltip {
            anchorItem: row
            offsetX: row.width + 14             // Fuera del menú: el padding de BarPopup (8), su borde y algo de aire
            besideItem: true
            text: row.tooltip
        }
    }
}
