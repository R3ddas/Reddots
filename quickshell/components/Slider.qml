// Barra de nivel con su porcentaje a la derecha: la de volumen (Volume.qml), las de
// brillo (BrightnessSliders.qml, en el selector de tema), la del indicador de las teclas
// multimedia (Osd.qml) y la del avance de la canción (Volume.qml, con el tiempo en vez del
// porcentaje: ver "label").
// Se arrastra o se hace clic para elegir el valor, y la rueda lo sube/baja de 5 en 5;
// con interactive: false es solo un indicador. No cambia "value" por sí misma:
// avisa con moved() y quien la usa decide (y acota) el valor nuevo.
import QtQuick
import QtQuick.Layouts
import qs.services

RowLayout {
    id: root

    property real maxValue: 1           // Valor que llena la barra entera (1.5 en el volumen con el aumento activado)
    property real value: 0              // De 0 a maxValue (lo que pase se pinta lleno)
    property bool dimmed: false         // Relleno en gris (p.ej. con el sonido silenciado)
    property bool interactive: true
    property int barHeight: 14
    signal moved(real value)            // Valor pedido (0-maxValue al arrastrar; con la rueda puede salirse de ese rango)

    readonly property real shown: Math.max(0, Math.min(value, maxValue)) / maxValue   // Fracción de barra rellena (0-1)
    property string label: Math.round(shown * maxValue * 100) + "%"   // Texto de la derecha: el porcentaje, salvo que se ponga otro (el tiempo de la canción en Volume.qml)

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
            onPressed: mouse => root.moved(mouse.x / width * root.maxValue)
            onPositionChanged: mouse => { if (pressed) root.moved(mouse.x / width * root.maxValue) }
            onWheel: wheel => root.moved(root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }

    Text {                              // Porcentaje (o el texto de "label")
        text: root.label
        color: Theme.textActive
        font.pixelSize: 11
        Layout.preferredWidth: Math.max(32, implicitWidth)     // 32 fijo para el porcentaje (que no baile la barra al pasar de 9 % a 10 %); más si el texto es más largo
    }
}
