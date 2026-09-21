
// Border.qml
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

PanelWindow {
    id: root

    property int thickness: Geometry.borderThickness
    property int rounding: Geometry.borderRounding
    property color frameColor: Theme.background

    // Sombra que el propio marco proyecta hacia adentro: se genera a partir
    // del alfa del marco (sus 6px), difuminado. blurMax controla cuánto se
    // "estira" hacia el interior; valores grandes diluyen la opacidad y la
    // hacen invisible, así que se mantiene moderado para que quede pegada
    // al borde en vez de invadir el resto de la pantalla.
    //
    // "Blur" es difuminado/desenfoque: en vez de un borde nítido entre
    // sombra y transparencia, cada píxel se mezcla con los de alrededor
    // (como una foto desenfocada), así que el corte pasa a ser un
    // degradado suave de opaco a transparente en vez de una línea dura.
    property color shadowColor: "#000000"     // color de la sombra
    property real shadowOpacity: 0.8         // opacidad máxima de la sombra (0 invisible, 1 totalmente opaca)
    property real shadowBlur: 1.0             // cuánto de "shadowBlurMax" se usa realmente (0 nada, 1 el máximo)
    property real shadowBlurMax: 40           // difuminado: cuántos píxeles hacia adentro se desvanece la sombra

    anchors { top: true; bottom: true; left: true; right: true }
    margins { left: Geometry.sidebarWidth }   // el ancho de tu barra

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "reddots:border"
    mask: Region {}        // click-through: no roba ningún clic

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.shadowColor
            shadowOpacity: root.shadowOpacity
            shadowBlur: root.shadowBlur
            blurMax: root.shadowBlurMax
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        ShapePath {
            fillRule: ShapePath.OddEvenFill
            fillColor: root.frameColor
            strokeWidth: 0

            PathRectangle { width: root.width; height: root.height }
            PathRectangle {
                x: root.thickness
                y: root.thickness
                width: root.width - root.thickness * 2
                height: root.height - root.thickness * 2
                radius: root.rounding
            }
        }
    }
}
