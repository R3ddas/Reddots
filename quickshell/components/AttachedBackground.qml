// Fondo del estilo "unido a la barra" (Geometry.popupAttached) de lo que sale a la derecha de
// un icono de la barra: los desplegables (BarPopup.qml) y las etiquetas (BarTooltip.qml). Del
// color de la barra y sin borde de color, con el lado izquierdo pegado al borde interior del marco
// de la pantalla y, donde se junta con él, dos curvas hacia dentro ("orejas", arriba y abajo).
// Las esquinas de la derecha van redondeadas.
//
// Quien lo usa lo pone de fondo de la ventana (anchors.fill) y la hace "ear" px más alta por
// arriba y por abajo para que quepan las orejas; lo de dentro, sin meterse en ellas.
import QtQuick
import QtQuick.Shapes
import qs.services

Shape {
    id: root

    property real ear: Geometry.popupRounding           // Alto (y ancho) de cada oreja
    // Esquinas de la derecha: las del tema, sin pasarse en algo pequeño (una etiqueta de una línea)
    readonly property real corner: Math.max(0, Math.min(Geometry.popupRounding, (height - ear * 2) / 2, width - ear))

    preferredRendererType: Shape.CurveRenderer

    // Coordenadas: x = 0 es el borde interior del marco. Se recorre así: oreja de arriba (curva
    // hacia dentro desde el marco hasta el borde de arriba), esquinas redondeadas de la derecha,
    // oreja de abajo, y se vuelve por el borde del marco
    ShapePath {
        fillColor: Theme.background             // El de la barra y el marco: así no se ve dónde acaba uno y empieza el otro
        strokeWidth: 0
        strokeColor: "transparent"
        startX: 0; startY: 0

        PathArc {                               // Oreja de arriba
            x: root.ear; y: root.ear
            radiusX: root.ear; radiusY: root.ear
            direction: PathArc.Counterclockwise
        }
        PathLine { x: root.width - root.corner; y: root.ear }
        PathArc {                               // Esquina de arriba a la derecha
            x: root.width; y: root.ear + root.corner
            radiusX: root.corner; radiusY: root.corner
        }
        PathLine { x: root.width; y: root.height - root.ear - root.corner }
        PathArc {                               // Esquina de abajo a la derecha
            x: root.width - root.corner; y: root.height - root.ear
            radiusX: root.corner; radiusY: root.corner
        }
        PathLine { x: root.ear; y: root.height - root.ear }
        PathArc {                               // Oreja de abajo
            x: 0; y: root.height
            radiusX: root.ear; radiusY: root.ear
            direction: PathArc.Counterclockwise
        }
        PathLine { x: 0; y: 0 }                 // Por el borde del marco, de vuelta arriba
    }
}
