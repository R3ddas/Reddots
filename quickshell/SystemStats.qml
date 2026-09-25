// Icono en la barra + popup con el uso del sistema: procesador, memoria (y swap) y las
// temperaturas del procesador, la gráfica y el disco. Los datos los lee SystemMonitor.qml
// (cada 15 s, y cada 2 s mientras este popup está abierto). Si alguna temperatura pasa
// de su umbral, el icono se pone en rojo (y el engranaje, ver SettingsToggle.qml).
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    // kB -> "6,2" (GiB, con coma decimal)
    function gib(kb) {
        return (kb / 1048576).toFixed(1).replace(".", ",")
    }

    Binding {                           // Con el panel abierto, lecturas cada 2 s
        target: SystemMonitor
        property: "fast"
        value: menu.visible
    }

    // Línea del popup: nombre a la izquierda y valor a la derecha
    component StatLine: RowLayout {
        id: line
        property string label
        property string value
        property color valueColor: Theme.textActive
        Layout.fillWidth: true
        Text { text: line.label; color: Theme.textActive; font.pixelSize: 11; Layout.fillWidth: true }
        Text { text: line.value; color: line.valueColor; font.pixelSize: 11; font.bold: true }
    }

    BarIcon {
        id: iconText
        text: String.fromCodePoint(0xF061A)  // chip
        color: SystemMonitor.overheating ? SystemMonitor.hotColor : Theme.textActive
        tooltip: menu.visible ? "" : "Uso del sistema" + (SystemMonitor.overheating ? "\nTemperatura alta: " + SystemMonitor.warning : "")
        onClicked: menu.toggle()
    }

    BarPopup {
        id: menu
        anchorItem: iconText
        implicitWidth: 240
        implicitHeight: listCol.implicitHeight + 16

        ColumnLayout {
            id: listCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            StatLine { label: "Procesador"; value: SystemMonitor.cpu < 0 ? "…" : "" }
            Slider { interactive: false; value: Math.max(0, SystemMonitor.cpu) }

            StatLine {
                Layout.topMargin: 4
                label: "Memoria"
                value: SystemMonitor.memTotal ? root.gib(SystemMonitor.memUsed) + " / " + root.gib(SystemMonitor.memTotal) + " GiB" : "…"
            }
            Slider { interactive: false; value: SystemMonitor.memTotal ? SystemMonitor.memUsed / SystemMonitor.memTotal : 0 }

            StatLine {
                visible: SystemMonitor.swapTotal > 0        // Sin swap no se pinta
                Layout.topMargin: 4
                label: "Swap"
                value: root.gib(SystemMonitor.swapUsed) + " / " + root.gib(SystemMonitor.swapTotal) + " GiB"
            }
            Slider { visible: SystemMonitor.swapTotal > 0; interactive: false; value: SystemMonitor.swapTotal ? SystemMonitor.swapUsed / SystemMonitor.swapTotal : 0 }

            Rectangle {                                     // Separador antes de las temperaturas
                visible: SystemMonitor.temps.length > 0
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 2
                implicitHeight: 1
                color: Theme.border
            }

            Repeater {
                model: SystemMonitor.temps
                delegate: StatLine {
                    required property var modelData
                    label: String.fromCodePoint(0xF050F) + "  " + modelData.name   // thermometer
                    value: modelData.celsius + " °C"
                    valueColor: modelData.hot ? SystemMonitor.hotColor : Theme.textActive   // La que pasa del umbral, en rojo
                }
            }
        }
    }
}
