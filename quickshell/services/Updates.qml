pragma Singleton
import Quickshell
import Quickshell.Io                // Para lanzar scripts/check-updates.sh y el IpcHandler
import QtQuick

// Actualizaciones pendientes del sistema (repos oficiales y AUR), para el tooltip y el
// menú de Reddots.qml. Las mira scripts/check-updates.sh solo al pasar el ratón por el
// logo de Reddots (Reddots.qml llama a refresh()), que es cuando se van a leer: sin
// consultas de fondo mientras no se mira. También con "qs ipc call updates refresh",
// que lanza update-reddots.sh al terminar.
Singleton {
    id: root

    property var repos: []          // "paquete versión -> nueva", de los repos oficiales
    property var aur: []            // Lo mismo, de AUR
    readonly property int count: repos.length + aur.length

    // "5 actualizaciones pendientes (3 de los repos, 2 de AUR)"
    readonly property string summary: count === 0 ? "Sistema al día"
        : count + (count === 1 ? " actualización pendiente" : " actualizaciones pendientes")
          + " (" + repos.length + " de los repos, " + aur.length + " de AUR)"

    function refresh() {
        if (!proc.running) proc.running = true      // Si ya está mirando, no se corta: ya llegará ese resultado
    }

    Process {
        id: proc
        command: [Quickshell.shellPath("scripts/check-updates.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l !== "")
                if (lines[lines.length - 1] !== "ok") return        // No se ha podido consultar: se queda con lo de antes
                root.repos = Utils.parseLines(text, "repos")
                root.aur = Utils.parseLines(text, "aur")
            }
        }
    }

    IpcHandler {
        target: "updates"

        function refresh(): void {
            root.refresh()
        }
    }
}
