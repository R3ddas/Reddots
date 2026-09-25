// Icono en la barra + popup con el uso del sistema: procesador, memoria (y swap) y las
// temperaturas del procesador, la gráfica y el disco. Los datos los da
// scripts/system-stats.sh, que solo se lanza (cada 2 s) mientras el popup está abierto:
// con él cerrado esto no gasta nada.
import Quickshell
import Quickshell.Io                // Para lanzar system-stats.sh
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    property var prevCpu: null      // Contadores de /proc/stat de la lectura anterior (el uso sale de la diferencia)
    property real cpu: -1           // Uso del procesador, de 0 a 1 (-1 = aún no hay dos lecturas)
    property real memTotal: 0       // kB
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property var temps: []          // [{ name, celsius }], en el orden de tempOrder

    readonly property var tempOrder: ["Procesador", "Gráfica", "Disco"]

    // kB -> "6,2" (GiB, con coma decimal)
    function gib(kb) {
        return (kb / 1048576).toFixed(1).replace(".", ",")
    }

    function parse(text) {
        const temps = []
        for (const line of text.split("\n")) {
            const f = line.split(" ")
            if (f[0] === "cpu") {
                const c = f.slice(1).map(Number)
                const idle = c[3] + c[4]                                    // idle + iowait
                const total = c.reduce((a, b) => a + b, 0)
                if (root.prevCpu && total > root.prevCpu.total)
                    root.cpu = 1 - (idle - root.prevCpu.idle) / (total - root.prevCpu.total)
                root.prevCpu = { idle: idle, total: total }
            } else if (f[0] === "mem") {
                root.memTotal = Number(f[1])
                root.memUsed = Number(f[1]) - Number(f[2])                  // Total - disponible (la caché que se puede liberar no cuenta)
            } else if (f[0] === "swap") {
                root.swapTotal = Number(f[1])
                root.swapUsed = Number(f[1]) - Number(f[2])
            } else if (line.startsWith("temp|")) {
                const t = line.split("|")
                temps.push({ name: t[1], celsius: Math.round(Number(t[2]) / 1000) })
            }
        }
        temps.sort((a, b) => root.tempOrder.indexOf(a.name) - root.tempOrder.indexOf(b.name))
        root.temps = temps
    }

    Process {
        id: statsProc
        command: [Quickshell.shellPath("scripts/system-stats.sh")]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    Timer {
        // La primera lectura solo sirve de referencia para el procesador, así que la
        // segunda llega enseguida (0,5 s) y a partir de ahí cada 2 s
        interval: root.prevCpu ? 2000 : 500
        running: menu.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!statsProc.running) statsProc.running = true
    }

    // Línea del popup: nombre a la izquierda y valor a la derecha
    component StatLine: RowLayout {
        id: line
        property string label
        property string value
        Layout.fillWidth: true
        Text { text: line.label; color: Theme.textActive; font.pixelSize: 11; Layout.fillWidth: true }
        Text { text: line.value; color: Theme.textActive; font.pixelSize: 11; font.bold: true }
    }

    BarIcon {
        id: iconText
        text: String.fromCodePoint(0xF061A)  // chip
        tooltip: menu.visible ? "" : "Uso del sistema"
        onClicked: menu.toggle()
    }

    BarPopup {
        id: menu
        anchorItem: iconText
        implicitWidth: 240
        implicitHeight: listCol.implicitHeight + 16

        onVisibleChanged: if (!visible) { root.prevCpu = null; root.cpu = -1 }   // Al volver a abrir, sin mezclar con la lectura de hace rato

        ColumnLayout {
            id: listCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            StatLine { label: "Procesador"; value: root.cpu < 0 ? "…" : "" }
            Slider { interactive: false; value: Math.max(0, root.cpu) }

            StatLine {
                Layout.topMargin: 4
                label: "Memoria"
                value: root.memTotal ? root.gib(root.memUsed) + " / " + root.gib(root.memTotal) + " GiB" : "…"
            }
            Slider { interactive: false; value: root.memTotal ? root.memUsed / root.memTotal : 0 }

            StatLine {
                visible: root.swapTotal > 0                 // Sin swap no se pinta
                Layout.topMargin: 4
                label: "Swap"
                value: root.gib(root.swapUsed) + " / " + root.gib(root.swapTotal) + " GiB"
            }
            Slider { visible: root.swapTotal > 0; interactive: false; value: root.swapTotal ? root.swapUsed / root.swapTotal : 0 }

            Rectangle {                                     // Separador antes de las temperaturas
                visible: root.temps.length > 0
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 2
                implicitHeight: 1
                color: Theme.border
            }

            Repeater {
                model: root.temps
                delegate: StatLine {
                    required property var modelData
                    label: String.fromCodePoint(0xF050F) + "  " + modelData.name   // thermometer
                    value: modelData.celsius + " °C"
                }
            }
        }
    }
}
