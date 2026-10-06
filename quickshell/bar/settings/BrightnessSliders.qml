// BrightnessSliders.qml
// Un slider de brillo por cada pantalla que lo permita (services/BrightnessMonitor.qml),
// con su nombre encima y el icono del brillo a la izquierda (como los del volumen en
// Volume.qml), para que se sepa qué es esa barra. Sale arriba del selector de tema
// (ThemeSettings.qml), que llama a BrightnessMonitor.refresh() al abrirse para que se relea
// el brillo real.
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

ColumnLayout {
    Layout.fillWidth: true
    spacing: 8

    Text {
        Layout.fillWidth: true
        visible: BrightnessMonitor.displays.count === 0
        text: BrightnessMonitor.searching ? "Buscando pantallas…" : "Ninguna pantalla permite\ncambiar el brillo"
        color: Theme.textDisabled
        font.pixelSize: 11
    }

    Repeater {
        model: BrightnessMonitor.displays

        delegate: ColumnLayout {
            id: row
            required property int index
            required property string label
            required property int percent

            Layout.fillWidth: true
            spacing: 4

            Text {
                text: row.label
                color: Theme.textActive
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: String.fromCodePoint(0xF00DF)     // brightness-6
                    color: Theme.textActive
                    font.pixelSize: 16                      // Como los iconos de silenciar de Volume.qml
                    Layout.preferredWidth: 20
                    horizontalAlignment: Text.AlignHCenter
                }

                // Slider: arrastrar o hacer scroll sobre la barra (igual que en Volume.qml)
                Slider {
                    value: row.percent / 100
                    onMoved: v => BrightnessMonitor.request(row.index, v * 100)
                }
            }
        }
    }
}
