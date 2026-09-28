
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
    property real shadowOpacity: Geometry.borderShadowOpacity / 100  // opacidad máxima de la sombra (0 invisible, 1 totalmente opaca); en Geometry va en %
    property real shadowBlur: 1.0             // cuánto de "shadowBlurMax" se usa realmente (0 nada, 1 el máximo)
    property int shadowBlurMax: Geometry.borderShadow  // difuminado: cuántos píxeles hacia adentro se desvanece la sombra (editable desde GeometrySettings.qml)

    anchors { top: true; bottom: true; left: true; right: true }
    margins { left: Geometry.sidebarWidth }   // el ancho de tu barra

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "reddots:border"
    mask: Region {}        // click-through: no roba ningún clic

    // El marco se dibuja más grande que la ventana ("bleed" px de más por
    // cada lado, que quedan fuera de pantalla y no se ven). Sin eso, la
    // sombra sale de difuminar solo los 6 px visibles del marco con lo que
    // hay fuera (nada, transparente): cuanto más se difumina, más se diluyen
    // esos 6 px y la sombra se ensancha pero se aclara hasta desaparecer
    // (medido: con 40 px apenas oscurecía un 7 %). Con el marco alargado
    // hacia fuera, el difuminado solo encuentra marco opaco por ese lado y
    // la sombra conserva la misma intensidad junto al borde sea cual sea su
    // tamaño; así el número del panel cambia lo lejos que llega, no si se ve.
    // Se deja el doble del difuminado para ir sobrados: el blur de
    // MultiEffect no corta exactamente en blurMax.
    readonly property int bleed: shadowBlurMax * 2

    Shape {
        anchors.fill: parent
        anchors.margins: -root.bleed      // Márgenes negativos: sobresale de la ventana por los cuatro lados
        preferredRendererType: Shape.CurveRenderer

        // Con 0 px (o 0 % de opacidad) no hay sombra que dibujar: se apaga la capa entera en vez
        // de dejar un MultiEffect que solo pintaría una copia nítida tapada
        // por el propio marco (y se ahorra el render a textura).
        layer.enabled: root.shadowBlurMax > 0 && root.shadowOpacity > 0
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

            // Coordenadas relativas al Shape, que empieza "bleed" px antes
            // que la ventana: el hueco interior se desplaza lo mismo para
            // que en pantalla quede exactamente donde estaba.
            PathRectangle { width: root.width + root.bleed * 2; height: root.height + root.bleed * 2 }
            PathRectangle {
                x: root.bleed + root.thickness
                y: root.bleed + root.thickness
                width: root.width - root.thickness * 2
                height: root.height - root.thickness * 2
                radius: root.rounding
            }
        }
    }
}
