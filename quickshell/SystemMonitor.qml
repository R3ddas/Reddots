pragma Singleton
import Quickshell
import Quickshell.Io                // Para lanzar scripts/system-stats.sh
import QtQuick

// Uso del sistema (procesador, memoria, swap y temperaturas), para el panel de
// SystemStats.qml y para el aviso de temperatura alta, que pone en rojo el icono del
// chip y, con el grupo plegado, el engranaje (SettingsToggle.qml). Lo lee
// scripts/system-stats.sh cada 15 s, y cada 2 s mientras el panel está abierto ("fast").
Singleton {
    id: root

    property bool fast: false       // El panel está abierto: lecturas más seguidas

    property var prevCpu: null      // Contadores de /proc/stat de la lectura anterior (el uso sale de la diferencia)
    property real cpu: -1           // Uso del procesador desde la lectura anterior, de 0 a 1 (-1 = aún no hay dos lecturas)
    property real memTotal: 0       // kB
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property var temps: []          // [{ name, celsius, hot }], en el orden de "limits"

    // Grados a partir de los que se avisa: cada pieza aguanta distinto. El orden de
    // aquí es también el orden en el que salen en el panel.
    readonly property var limits: ({ "Procesador": 85, "Gráfica": 90, "Disco": 70 })
    readonly property color hotColor: "#ff0000"     // Rojo fijo, como el borde de las notificaciones críticas: se ve en todos los temas

    readonly property var hot: temps.filter(t => t.hot)
    readonly property bool overheating: hot.length > 0
    readonly property string warning: hot.map(t => t.name + " a " + t.celsius + " °C").join(", ")   // "Procesador a 91 °C"

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
                const celsius = Math.round(Number(t[2]) / 1000)
                temps.push({ name: t[1], celsius: celsius, hot: celsius >= (root.limits[t[1]] ?? 999) })
            }
        }
        const order = Object.keys(root.limits)
        temps.sort((a, b) => order.indexOf(a.name) - order.indexOf(b.name))
        root.temps = temps
    }

    Process {
        id: statsProc
        command: [Quickshell.shellPath("scripts/system-stats.sh")]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    Timer {
        interval: root.fast ? 2000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!statsProc.running) statsProc.running = true
    }

    onFastChanged: if (fast && !statsProc.running) statsProc.running = true    // Al abrir el panel, datos al momento
}
