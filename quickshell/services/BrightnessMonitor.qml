pragma Singleton
import Quickshell
import Quickshell.Io                // Para lanzar brightness-list.sh, brightnessctl y ddcutil
import QtQuick

// Brillo de las pantallas que lo permiten: el panel del portátil (brightnessctl) y los
// monitores externos que respondan por DDC/CI (ddcutil). Qué pantallas hay lo averigua
// scripts/brightness-list.sh al poco de arrancar y cada vez que se abre el selector de tema,
// donde están los sliders (refresh()); así también se ve si se ha tocado desde los botones
// del monitor o con las teclas de brillo. Lo que se ve está en bar/settings/BrightnessSliders.qml.
//
// Está aquí y no en el desplegable porque la barra se destruye y se vuelve a crear al cerrar
// la tapa o cambiar de monitor: así la búsqueda de arranque (abajo) se hace una sola vez
// por sesión de Quickshell y la lista no se pierde con la barra.
Singleton {
    id: root

    readonly property ListModel displays: ListModel {}     // Una fila por pantalla: kind, target, label, percent, max
    readonly property bool searching: listProc.running     // Buscando pantallas (para el "Buscando pantallas…")

    // Se busca una vez en segundo plano al poco de arrancar (prefetch, abajo) y otra cada vez
    // que se abre el selector de tema. Sin la primera, al abrirlo por primera vez
    // había que esperar a "ddcutil detect" y a la consulta DDC, que justo tras arrancar
    // (monitor recién despertado) es cuando más tardan. Así se abre ya con la lista de la
    // última búsqueda, y los valores se actualizan solos al terminar la nueva.
    //
    // Si ya hay una búsqueda en marcha (p. ej. se abre el popup durante la de arranque) no se
    // reinicia: su resultado llega antes que el de una nueva, y matar ddcutil a mitad de una
    // consulta DDC puede dejar al monitor sin responder un rato.
    function refresh() {
        if (!listProc.running) listProc.running = true
    }

    // Unos segundos de margen: al arrancar Hyprland aún está configurando los monitores, y una
    // consulta DDC en mitad de un cambio de modo puede fallar (el monitor se omitiría de la lista
    // hasta la siguiente búsqueda). Tampoco compite así con el resto del arranque.
    // Esto no me gusta nada, pero no tengo una alternativa mejor para que no tarde tanto el widget de brightness la primera vez que lo abro (se ejecuta 1 vez, a los 3s de lanzar quickshell)
    Timer {
        interval: 3000
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: listProc
        command: [Quickshell.shellPath("scripts/brightness-list.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.trim().split("\n").filter(l => l !== "").map(l => {
                    const f = l.split("|")   // tipo|objetivo|nombre|porcentaje|máximo
                    return { kind: f[0], target: f[1], label: f[2], percent: parseInt(f[3]), max: parseInt(f[4]) }
                })
                // Si son las mismas pantallas solo se actualiza el valor, para no
                // recrear los sliders (y cortar un arrastre) mientras el popup está abierto
                const same = rows.length === root.displays.count
                    && rows.every((r, i) => root.displays.get(i).kind === r.kind && root.displays.get(i).target === r.target)
                if (same) {
                    rows.forEach((r, i) => root.displays.setProperty(i, "percent", r.percent))
                } else {
                    root.pending = ({})         // Lo pedido era para las pantallas de antes
                    root.displays.clear()
                    rows.forEach(r => root.displays.append(r))
                }
            }
        }
    }

    // Cambiar el brillo por DDC tarda: mientras un comando está en marcha no se lanza otro,
    // se guarda el último valor pedido para cada pantalla y se envía al terminar (así
    // arrastrar el slider no encola decenas). Un solo Process para todas las pantallas:
    // solo se arrastra un slider a la vez, y así tampoco se pisan dos órdenes DDC.
    property var pending: ({})          // Índice de la pantalla -> último porcentaje pedido

    function request(index, value) {
        const v = Math.max(1, Math.min(100, Math.round(value)))   // Mínimo 1: a 0 algunas pantallas se apagan del todo
        displays.setProperty(index, "percent", v)                // El slider responde al momento
        pending[index] = v
        if (!setProc.running) sendPending()
    }

    function sendPending() {
        const keys = Object.keys(pending)
        if (keys.length === 0) return
        const index = parseInt(keys[0])
        const v = pending[index]
        delete pending[index]
        const d = displays.get(index)
        setProc.command = d.kind === "backlight"
            ? ["brightnessctl", "-d", d.target, "set", v + "%"]
            : ["ddcutil", "--bus", d.target, "--noverify", "setvcp", "10", String(Math.round(v * d.max / 100))]
        setProc.running = true
    }

    Process {
        id: setProc
        onExited: root.sendPending()    // Si se ha movido un slider mientras tanto, manda el último valor
    }
}
