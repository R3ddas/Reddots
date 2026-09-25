// Slider.qml
// Barra de nivel con su porcentaje a la derecha: la de volumen (Volume.qml), las de
// brillo (Brightness.qml) y la del indicador de las teclas multimedia (Osd.qml).
// Se arrastra o se hace clic para elegir el valor, y la rueda lo sube/baja de 5 en 5;
// con interactive: false es solo un indicador. No cambia "value" por sí misma:
// avisa con moved() y quien la usa decide (y acota) el valor nuevo.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property real value: 0              // De 0 a 1 (lo que pase de 1 se pinta lleno)
    property bool dimmed: false         // Relleno en gris (p.ej. con el sonido silenciado)
    property bool interactive: true
    property int barHeight: 14
    signal moved(real value)            // Valor pedido (0-1 al arrastrar; con la rueda puede salirse de ese rango)

    readonly property real shown: Math.max(0, Math.min(value, 1))

    Layout.fillWidth: true
    spacing: 6

    Rectangle {                         // Barra
        Layout.fillWidth: true
        implicitHeight: root.barHeight
        radius: root.barHeight / 2
        color: Theme.background
        border.color: Theme.border

        Rectangle {                     // Relleno
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.shown
            radius: parent.radius
            color: root.dimmed ? Theme.textDisabled : Theme.textSelected
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.interactive
            onPressed: mouse => root.moved(mouse.x / width)
            onPositionChanged: mouse => { if (pressed) root.moved(mouse.x / width) }
            onWheel: wheel => root.moved(root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }

    Text {                              // Porcentaje
        text: Math.round(root.shown * 100) + "%"
        color: Theme.textActive
        font.pixelSize: 11
        Layout.preferredWidth: 32
    }
}
