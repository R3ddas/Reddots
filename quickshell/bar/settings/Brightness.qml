// Icono en la barra + popup con un slider de brillo por cada pantalla que lo permita:
// el panel del portátil (brightnessctl) y los monitores externos que respondan por
// DDC/CI (ddcutil). Qué pantallas hay lo averigua scripts/brightness-list.sh al poco de
// arrancar y cada vez que se abre el popup (así también se ve si se ha tocado desde los
// botones del monitor o con las teclas de brillo).
import Quickshell
import Quickshell.Io                // Para lanzar brightness-list.sh, brightnessctl y ddcutil
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 6

    ListModel { id: displays }      // Una fila por pantalla: kind, target, label, percent, max

    // Se busca una vez en segundo plano al poco de arrancar (prefetch, abajo) y otra cada vez
    // que se abre el popup (ver onVisibleChanged, más abajo). Sin la primera, al abrirlo por
    // primera vez había que esperar a "ddcutil detect" y a la consulta DDC, que justo tras
    // arrancar (monitor recién despertado) es cuando más tardan. Así se abre ya con la lista
    // de la última búsqueda, y los valores se actualizan solos al terminar la nueva.
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
    // Esto no me gusta nada, pero no tengo una alternativa mejor para que no tarde tanto el wiget de brightnesss lap rimera vez que lo abro
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
                const same = rows.length === displays.count
                    && rows.every((r, i) => displays.get(i).kind === r.kind && displays.get(i).target === r.target)
                if (same) {
                    rows.forEach((r, i) => displays.setProperty(i, "percent", r.percent))
                } else {
                    displays.clear()
                    rows.forEach(r => displays.append(r))
                }
            }
        }
    }

    BarIcon {
        id: iconText
        text: String.fromCodePoint(0xF00DF)  // brightness-6
        tooltip: "Brillo de las pantallas"
        popup: menu
    }

    BarPopup {
        id: menu
        anchorItem: iconText
        implicitWidth: 240
        spacing: 8

        onVisibleChanged: if (visible) root.refresh()     // Relee el brillo real al abrir

        Text {
            Layout.fillWidth: true
            visible: displays.count === 0
            text: listProc.running ? "Buscando pantallas…" : "Ninguna pantalla permite\ncambiar el brillo"
            color: Theme.textDisabled
            font.pixelSize: 11
        }

        Repeater {
            model: displays

            delegate: ColumnLayout {
                id: row
                required property int index
                required property string kind
                required property string target
                required property string label
                required property int percent
                required property int max

                Layout.fillWidth: true
                spacing: 4

                // Cambiar el brillo por DDC tarda: mientras un comando está en
                // marcha no se lanza otro, se guarda el último valor pedido
                // y se envía al terminar (así arrastrar el slider no encola decenas)
                property int pending: -1

                function request(value) {
                    const v = Math.max(1, Math.min(100, Math.round(value)))   // Mínimo 1: a 0 algunas pantallas se apagan del todo
                    displays.setProperty(row.index, "percent", v)            // El slider responde al momento
                    row.pending = v
                    if (!setProc.running) row.sendPending()
                }

                function sendPending() {
                    if (row.pending < 0) return
                    const v = row.pending
                    row.pending = -1
                    setProc.command = row.kind === "backlight"
                        ? ["brightnessctl", "-d", row.target, "set", v + "%"]
                        : ["ddcutil", "--bus", row.target, "--noverify", "setvcp", "10", String(Math.round(v * row.max / 100))]
                    setProc.running = true
                }

                Process {
                    id: setProc
                    onExited: row.sendPending()     // Si se ha movido el slider mientras tanto, manda el último valor
                }

                Text {
                    text: row.label
                    color: Theme.textActive
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Slider: arrastrar o hacer scroll sobre la barra (igual que en Volume.qml)
                Slider {
                    value: row.percent / 100
                    onMoved: v => row.request(v * 100)
                }
            }
        }
    }
}
