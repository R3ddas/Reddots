
// Border.qml
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

PanelWindow {
    id: root

    property int thickness: Geometry.borderThickness
    property int rounding: Geometry.borderRounding
    property color frameColor: Theme.background

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
