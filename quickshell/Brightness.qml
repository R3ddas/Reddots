// Icono en la barra + popup con un slider de brillo por cada pantalla que lo permita:
// el panel del portátil (brightnessctl) y los monitores externos que respondan por
// DDC/CI (ddcutil). Qué pantallas hay lo averigua scripts/brightness-list.sh, al
// arrancar y cada vez que se abre el popup (por si se ha tocado desde los botones
// del monitor o con las teclas de brillo).
import Quickshell
import Quickshell.Io                // Para lanzar brightness-list.sh, brightnessctl y ddcutil
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    ListModel { id: displays }      // Una fila por pantalla: kind, target, label, percent, max

    Component.onCompleted: refresh()

    function refresh() {
        listProc.running = false
        listProc.running = true
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
        onClicked: menu.toggle()
    }

    BarPopup {
        id: menu
        anchorItem: iconText

        implicitWidth: 240
        implicitHeight: Math.max(40, listCol.implicitHeight + 16)

        onVisibleChanged: if (visible) root.refresh()     // Relee el brillo real al abrir

        ColumnLayout {
            id: listCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

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
}
