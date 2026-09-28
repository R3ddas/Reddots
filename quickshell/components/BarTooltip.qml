// BarTooltip.qml
// Etiqueta que aparece a la derecha de un icono de la barra al dejar el ratón encima
// un momento (red, volumen, batería...). Quien la usa le dice junto a qué icono sale
// ("anchorItem"), qué texto pone y si el ratón está encima ("hovered"); aquí se espera
// el retardo y se coloca como los desplegables (BarPopup.qml), pero sin grab: no roba
// ni el foco ni los clics.
import Quickshell
import QtQuick

PopupWindow {
    id: root

    property Item anchorItem: null
    property string text: ""
    property bool hovered: false        // El ratón está sobre el icono
    property int delay: 500             // ms con el ratón quieto encima antes de aparecer

    visible: false
    color: "transparent"
    mask: Region {}                     // Transparente a los clics: no estorba al icono ni a lo que haya debajo

    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 10

    anchor.item: anchorItem
    anchor.rect.x: Geometry.sidebarWidth            // Igual que los desplegables: a partir del borde derecho de la barra
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.onAnchoring: if (anchorItem) anchor.rect.y = Geometry.popupY(anchorItem, anchor.rect.x, implicitHeight)  // Centrada con el icono

    Component.onCompleted: if (hovered && text !== "") showTimer.restart()   // Si se crea ya con el ratón encima (BarIcon), onHoveredChanged no salta
    onHoveredChanged: {
        if (hovered && text !== "") showTimer.restart()
        else { showTimer.stop(); visible = false }
    }
    onTextChanged: if (text === "") visible = false        // Si deja de tener texto (p.ej. se abre el menú del icono), se quita

    Timer {
        id: showTimer
        interval: root.delay
        onTriggered: root.visible = root.hovered && root.text !== ""
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: 6
        border.color: Theme.border
        border.width: 1

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.textActive
            font.pixelSize: 11
        }
    }
}
