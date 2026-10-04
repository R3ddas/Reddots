pragma Singleton
import Quickshell
import Quickshell.Io                // FileView para leer /proc y los sensores; Process para buscar los sensores
import QtQuick

// Uso del sistema (procesador, memoria, swap, gráfica y temperaturas), para el panel de
// SystemStats.qml y para el aviso de temperatura alta, que pone en rojo el icono del
// chip y, con el grupo plegado, el engranaje (SettingsToggle.qml). Se lee cada 15 s, y
// cada 2 s mientras el panel está abierto ("fast").
//
// Los datos se leen directamente de /proc y /sys con FileView, sin lanzar ningún
// proceso en cada lectura (antes era un script con bash y awk cada vez, y es lo único
// de la barra que se repite siempre, se mire o no). Solo para saber DÓNDE están los
// sensores (temperaturas y uso de la gráfica) se lanza scripts/sensors.sh, una vez al arrancar.
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

    // La gráfica: solo con una AMD, que lo da en archivos (ver scripts/sensors.sh). En los
    // demás equipos (NVIDIA, Intel) se quedan en -1 / 0 y el panel no pinta esas líneas.
    // gpu_busy_percent es el uso en ese instante, no una media: con una lectura cada 2 s
    // con el panel abierto basta para ver si está trabajando.
    //
    // NVIDIA (la del portátil) no está hecho a propósito. Con el driver propietario no hay
    // archivos que leer: todo pasa por nvidia-smi (viene con nvidia-utils, que ya instala el
    // driver). Si algún día se quiere, los pasos serían:
    //   1. En scripts/sensors.sh, si no ha encontrado una AMD y existe nvidia-smi
    //      (command -v nvidia-smi), escribir una línea "gpu|nvidia|" para que esto lo sepa.
    //   2. Aquí, un Process con:
    //        nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu
    //                   --format=csv,noheader,nounits
    //      Escribe una línea como "12, 1024, 8192, 45": uso en %, memoria en MiB (×1024 para
    //      pasarla a kB, como vramUsed/vramTotal) y temperatura en °C (con el driver
    //      propietario la gráfica no sale en /sys/class/hwmon, así que tampoco hay
    //      temperatura de "Gráfica" por la otra vía: habría que meterla en "readings").
    //      Se parsea en su StdioCollector, como hace Updates.qml con check-updates.sh.
    //   3. Lanzarlo desde update() solo con el panel abierto ("fast"): cada lectura es un
    //      proceso que además despierta la gráfica, y en un portátil eso gasta batería si se
    //      hace cada 15 s aunque nadie mire. Por eso con el panel cerrado no se sabría la
    //      temperatura de la gráfica ni avisaría si se calienta.
    //   Otra forma, sin un proceso por lectura: dejar en marcha mientras el panel está
    //   abierto "nvidia-smi --query-gpu=... --format=csv,noheader,nounits -lms 2000", que
    //   escribe una línea cada 2 s, leerlas con un SplitParser y pararlo al cerrar el panel.
    property var gpuFiles: ({})     // { busy, vramUsed, vramTotal }: rutas que da sensors.sh (vacío si no hay)
    property real gpu: -1           // Uso, de 0 a 1 (-1 = no se sabe)
    property real vramTotal: 0      // kB, como la memoria (para que SystemStats.qml la escriba igual)
    property real vramUsed: 0

    // Grados a partir de los que se avisa: cada pieza aguanta distinto. El orden de
    // aquí es también el orden en el que salen en el panel.
    readonly property var limits: ({ "Procesador": 85, "Gráfica": 90, "Disco": 70 })
    readonly property color hotColor: Theme.error   // El rojo del tema, como el borde de las notificaciones críticas

    property var sensors: []        // [{ name, path }] de las temperaturas que da sensors.sh, en el orden de "limits"
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
        for (const f of [gpuBusyFile, vramUsedFile, vramTotalFile]) if (f.path !== "") f.reload()
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
        command: [Quickshell.shellPath("scripts/sensors.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.includes("|")).map(l => l.split("|"))   // [tipo, nombre, ruta]
                const order = Object.keys(root.limits)
                root.sensors = lines.filter(f => f[0] === "temp").map(f => ({ name: f[1], path: f[2] }))
                                    .sort((a, b) => order.indexOf(a.name) - order.indexOf(b.name))
                const gpu = {}
                for (const f of lines.filter(f => f[0] === "gpu")) gpu[f[1]] = f[2]
                root.gpuFiles = gpu
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

    // La gráfica: un archivo por dato, como los sensores. Sin ruta (no es una AMD) no se leen
    FileView {
        id: gpuBusyFile
        path: root.gpuFiles.busy ?? ""
        onLoaded: root.gpu = Number(text()) / 100
    }

    FileView {
        id: vramUsedFile
        path: root.gpuFiles.vramUsed ?? ""
        onLoaded: root.vramUsed = Number(text()) / 1024         // Bytes -> kB
    }

    FileView {
        id: vramTotalFile
        path: root.gpuFiles.vramTotal ?? ""
        onLoaded: root.vramTotal = Number(text()) / 1024
    }

    Timer {
        interval: root.fast ? 2000 : 15000
        running: true
        repeat: true
        onTriggered: root.update()
    }

    onFastChanged: if (fast) update()    // Al abrir el panel, datos al momento
}
