// MenuRow.qml
// Fila de un menú de la barra (Power, Screenshot, Reddots, Tray): icono, texto y,
// si hace falta, un aviso debajo ("hint") y una flecha de submenú. Resalta con el
// ratón encima y avisa con clicked().
import Quickshell
import Quickshell.Widgets           // Para el IconImage
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: row

    property string icon: ""            // Glifo de la Nerd Font (o "✓", "‹"...); se ignora si hay iconSource
    property string iconSource: ""      // Icono como imagen (los de los menús de la bandeja)
    property string text: ""
    property string hint: ""            // Aviso de qué va a pasar, en pequeño debajo del texto
    property bool arrow: false          // Tiene submenú: flecha a la derecha
    property bool active: true          // false = en gris y sin reaccionar al ratón
    signal clicked()

    Layout.fillWidth: true
    implicitWidth: label.implicitWidth + 28 + 16 + (arrow ? 20 : 0)    // Lo que pide el texto: para los menús que se ajustan a él (Tray)
    implicitHeight: hint !== "" ? col.implicitHeight + 10 : 28
    radius: 4
    color: rowMouse.containsMouse && active ? Theme.surfaceHover : "transparent"

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
                color: row.active ? Theme.textActive : Theme.textDisabled
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
                color: row.active ? Theme.textActive : Theme.textDisabled
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

        Text {                                          // Aviso, alineado con el texto y no con el icono
            visible: row.hint !== ""
            text: row.hint
            color: Theme.textDisabled
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.leftMargin: 28
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: row.active
        onClicked: row.clicked()
    }
}
