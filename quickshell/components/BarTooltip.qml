// Etiqueta que aparece a la derecha de un icono de la barra al dejar el ratón encima
// un momento (red, volumen, batería...). Solo existe mientras el ratón está encima: la crea
// TooltipArea.qml al entrar y la destruye al salir. Quien la usa le dice junto a qué icono
// sale ("anchorItem") y qué texto pone; aquí se espera el retardo y se coloca como los
// desplegables (BarPopup.qml), pero sin grab: no roba ni el foco ni los clics. También la
// usan las filas de los menús (MenuRow.qml), con besideItem: a la derecha del menú.
//
// Con los desplegables "unidos a la barra" (Geometry.popupAttached), las de los iconos de la barra
// salen también unidas, igual que ellos (AttachedBackground.qml). Las de las filas de un menú, no:
// salen a la derecha del menú, lejos del marco.
import Quickshell
import QtQuick
import qs.services

PopupWindow {
    id: root

    property Item anchorItem: null
    property string text: ""
    property string hint: ""            // Qué hace cada botón o la rueda ("Clic: …", una por línea): debajo, en pequeño y en gris
    readonly property bool hasContent: text !== "" || hint !== ""
    property int delay: 500             // ms con el ratón quieto encima antes de aparecer
    property real offsetX: Geometry.sidebarWidth    // Dónde empieza, desde el borde izquierdo de anchorItem: tras la barra, como los desplegables
    // false (iconos de la barra): se coloca como los desplegables, sin salirse de la pantalla
    // (Geometry.popupY). true (filas de un menú, que ya está dentro de la pantalla): solo
    // centrada en vertical con anchorItem; popupY no vale ahí, porque mide la ventana del menú
    property bool besideItem: false

    readonly property bool attached: Geometry.popupAttached && !besideItem
    readonly property int ear: attached ? Geometry.popupRounding : 0      // Las orejas del estilo unido, arriba y abajo
    // Dónde está el icono dentro de la barra (x), para empezar justo en el borde interior del marco
    // en el estilo unido. Se apunta al colocarla, como en BarPopup.qml
    property real anchorItemX: 0

    visible: false
    color: "transparent"
    mask: Region {}                     // Transparente a los clics: no estorba al icono ni a lo que haya debajo

    implicitWidth: content.implicitWidth + 16
    implicitHeight: content.implicitHeight + 10 + ear * 2

    anchor.item: anchorItem
    anchor.rect.x: attached ? Geometry.sidebarWidth + Geometry.borderThickness - anchorItemX : offsetX
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.onAnchoring: {
        if (!anchorItem) return
        anchorItemX = anchorItem.mapToItem(null, 0, 0).x       // Antes que la y: popupY usa anchor.rect.x, que depende de esto
        anchor.rect.y = besideItem ? (anchorItem.height - implicitHeight) / 2
                                   : Geometry.popupY(anchorItem, anchor.rect.x, implicitHeight)  // Centrada con el icono
    }

    Component.onCompleted: showTimer.start()                // Se crea al entrar el ratón: sale tras el retardo
    onHasContentChanged: if (!hasContent) visible = false  // Si se queda sin texto (p.ej. se abre el menú del icono), se quita

    Timer {
        id: showTimer
        interval: root.delay
        onTriggered: root.visible = root.hasContent
    }

    Rectangle {                         // Suelta
        anchors.fill: parent
        visible: !root.attached
        color: Theme.surface
        radius: 6
        border.color: Theme.border
        border.width: 1
    }

    AttachedBackground {                // Unida
        anchors.fill: parent
        visible: root.attached
        ear: root.ear
    }

    Column {
        id: content
        anchors.centerIn: parent            // Las orejas son iguales arriba y abajo: sigue centrado con lo de dentro
        spacing: 3

        Text {
            visible: root.text !== ""
            text: root.text
            color: Theme.textActive
            font.pixelSize: 11
        }
        Text {
            visible: root.hint !== ""
            text: root.hint
            color: Theme.textDisabled
            font.pixelSize: 10
        }
    }
}
