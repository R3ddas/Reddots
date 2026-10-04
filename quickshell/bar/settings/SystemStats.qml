// Icono en la barra + popup con el uso del sistema: procesador, memoria (y swap), gráfica
// (uso y memoria de vídeo, solo con una AMD: ver SystemMonitor.qml) y las temperaturas del
// procesador, la gráfica y el disco. Los datos los lee SystemMonitor.qml
// (cada 15 s, y cada 2 s mientras este popup está abierto). Si alguna temperatura pasa
// de su umbral, el icono se pone en rojo (y el engranaje, ver SettingsToggle.qml).
// Debajo, las notificaciones: las activas y las últimas descartadas
// (NotificationList.qml). Van aquí para no añadir otro icono a la barra. Bajo
// el chip sale cuántas activas hay, y si alguna es crítica se pone en rojo, como con una
// temperatura alta.
import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

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

    readonly property int notificationCount: NotificationCenter.active.length
    readonly property color iconColor: SystemMonitor.overheating || NotificationCenter.hasCritical ? SystemMonitor.hotColor : Theme.textActive

    BarIcon {
        id: iconText
        text: String.fromCodePoint(0xF061A)  // chip
        color: root.iconColor
        tooltip: "Uso del sistema y notificaciones"
                 + (SystemMonitor.overheating ? "\nTemperatura alta: " + SystemMonitor.warning : "")
                 + (root.notificationCount === 1 ? "\n1 notificación sin descartar"
                    : root.notificationCount > 1 ? "\n" + root.notificationCount + " notificaciones sin descartar" : "")
        popup: menu
    }

    Text {                                              // Cuántas notificaciones activas hay
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: -4                            // Pegado al chip (el layout deja 6 entre los dos)
        visible: root.notificationCount > 0             // Sin ninguna, no ocupa sitio
        text: root.notificationCount > 99 ? "99+" : root.notificationCount
        color: root.iconColor
        font.pixelSize: 10
    }

    BarPopup {
        id: menu
        anchorItem: iconText
        implicitWidth: 340                              // Más ancho que el resto de menús: las notificaciones necesitan sitio para el texto

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

        // La gráfica, como el procesador y la memoria. Sin datos (no es una AMD) no se pinta
        StatLine { visible: SystemMonitor.gpu >= 0; Layout.topMargin: 4; label: "Gráfica"; value: "" }
        Slider { visible: SystemMonitor.gpu >= 0; interactive: false; value: Math.max(0, SystemMonitor.gpu) }

        StatLine {
            visible: SystemMonitor.vramTotal > 0
            Layout.topMargin: 4
            label: "Memoria de vídeo"
            value: root.gib(SystemMonitor.vramUsed) + " / " + root.gib(SystemMonitor.vramTotal) + " GiB"
        }
        Slider { visible: SystemMonitor.vramTotal > 0; interactive: false; value: SystemMonitor.vramTotal ? SystemMonitor.vramUsed / SystemMonitor.vramTotal : 0 }

        Separator {                                     // Antes de las temperaturas
            visible: SystemMonitor.temps.length > 0
            Layout.topMargin: 4
            Layout.bottomMargin: 2
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

        Separator { Layout.topMargin: 6; Layout.bottomMargin: 4 }    // Antes de las notificaciones

        // Las notificaciones, con su propio desplazamiento: crecen hasta un máximo y a partir
        // de ahí se mueven con la rueda, sin que el uso del sistema se salga de la vista
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(notificationList.implicitHeight, 420)
            contentHeight: notificationList.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            NotificationList {
                id: notificationList
                width: parent.width
                onActionInvoked: menu.visible = false
            }
        }
    }
}
