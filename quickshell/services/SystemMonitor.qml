pragma Singleton
import Quickshell
import Quickshell.Io                // FileView para leer /proc y los sensores; Process para buscar los sensores
import QtQuick

// Uso del sistema (procesador, memoria, swap y temperaturas), para el panel de
// SystemStats.qml y para el aviso de temperatura alta, que pone en rojo el icono del
// chip y, con el grupo plegado, el engranaje (SettingsToggle.qml). Se lee cada 15 s, y
// cada 2 s mientras el panel está abierto ("fast").
//
// Los datos se leen directamente de /proc y /sys con FileView, sin lanzar ningún
// proceso en cada lectura (antes era un script con bash y awk cada vez, y es lo único
// de la barra que se repite siempre, se mire o no). Solo para saber DÓNDE están los
// sensores de temperatura se lanza scripts/temp-sensors.sh, una vez al arrancar.
//
// Ojo: tras reload(), text() aún devuelve la lectura anterior; la nueva llega en
// onLoaded. Por eso cada archivo se procesa en su onLoaded y no justo después de reload().
Singleton {
    id: root

    property bool fast: false       // El panel está abierto: lecturas más seguidas

    property var prevCpu: null      // Contadores de /proc/stat de la lectura anterior (el uso sale de la diferencia)
    property real cpu: -1           // Uso del procesador desde la lectura anterior, de 0 a 1 (-1 = aún no hay dos lecturas)
    property real memTotal: 0       // kB
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0

    // Grados a partir de los que se avisa: cada pieza aguanta distinto. El orden de
    // aquí es también el orden en el que salen en el panel.
    readonly property var limits: ({ "Procesador": 85, "Gráfica": 90, "Disco": 70 })
    readonly property color hotColor: Theme.error   // El rojo del tema, como el borde de las notificaciones críticas

    property var sensors: []        // [{ name, path }] que da temp-sensors.sh, en el orden de "limits"
    property var readings: ({})     // nombre -> °C de la última lectura de cada sensor

    readonly property var temps: sensors.filter(s => readings[s.name] !== undefined).map(s => ({   // [{ name, celsius, hot }]
        name: s.name,
        celsius: readings[s.name],
        hot: readings[s.name] >= (limits[s.name] ?? 999)
    }))
    readonly property var hot: temps.filter(t => t.hot)
    readonly property bool overheating: hot.length > 0
    readonly property string warning: hot.map(t => t.name + " a " + t.celsius + " °C").join(", ")   // "Procesador a 91 °C"

    // Primera línea de /proc/stat: "cpu  <user> <nice> <system> <idle> <iowait> <irq> <softirq> <steal> <guest> <guest_nice>".
    // Solo se suman los ocho primeros: guest y guest_nice ya van incluidos en user y nice.
    function parseCpu(text) {
        const c = text.slice(0, text.indexOf("\n")).split(/\s+/).slice(1, 9).map(Number)
        const idle = c[3] + c[4]                                            // idle + iowait
        const total = c.reduce((a, b) => a + b, 0)
        if (root.prevCpu && total > root.prevCpu.total)
            root.cpu = 1 - (idle - root.prevCpu.idle) / (total - root.prevCpu.total)
        root.prevCpu = { idle: idle, total: total }
    }

    // /proc/meminfo: líneas "MemTotal:  16314696 kB"
    function parseMem(text) {
        const kb = key => Number((text.match(new RegExp("^" + key + ":\\s+(\\d+)", "m")) ?? [])[1] ?? 0)
        root.memTotal = kb("MemTotal")
        root.memUsed = root.memTotal - kb("MemAvailable")                   // Total - disponible (la caché que se puede liberar no cuenta)
        root.swapTotal = kb("SwapTotal")
        root.swapUsed = root.swapTotal - kb("SwapFree")
    }

    function update() {
        statFile.reload()
        memFile.reload()
        for (let i = 0; i < sensorFiles.count; i++) sensorFiles.objectAt(i).reload()
    }

    // Se leen solos una vez al crearse: esa primera lectura del procesador solo sirve de
    // referencia para la siguiente (por eso el Timer no tiene triggeredOnStart: con dos
    // lecturas casi seguidas el uso saldría disparatado)
    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: root.parseCpu(text())
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: root.parseMem(text())
    }

    // Una sola vez: los sensores no cambian mientras el equipo está encendido
    Process {
        running: true
        command: [Quickshell.shellPath("scripts/temp-sensors.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const order = Object.keys(root.limits)
                root.sensors = text.split("\n").filter(l => l.includes("|")).map(l => {
                    const [name, path] = l.split("|")
                    return { name: name, path: path }
                }).sort((a, b) => order.indexOf(a.name) - order.indexOf(b.name))
            }
        }
    }

    // Un FileView por sensor (en milésimas de °C)
    Instantiator {
        id: sensorFiles
        model: root.sensors
        delegate: FileView {
            required property var modelData
            path: modelData.path
            onLoaded: {
                const celsius = Math.round(Number(text()) / 1000)
                if (isNaN(celsius)) return
                const next = Object.assign({}, root.readings)               // Objeto nuevo: si se cambia por dentro, QML no se entera
                next[modelData.name] = celsius
                root.readings = next
            }
        }
    }

    Timer {
        interval: root.fast ? 2000 : 15000
        running: true
        repeat: true
        onTriggered: root.update()
    }

    onFastChanged: if (fast) update()    // Al abrir el panel, datos al momento
}
