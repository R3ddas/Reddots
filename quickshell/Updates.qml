pragma Singleton
import Quickshell
import Quickshell.Io                // Para lanzar scripts/check-updates.sh y el IpcHandler
import QtQuick

// Actualizaciones pendientes del sistema (repos oficiales y AUR), para el contador de
// la barra (Reddots.qml y el engranaje de SettingsToggle.qml). Las mira
// scripts/check-updates.sh un minuto después de arrancar (para no competir con el
// arranque ni mirar antes de que haya red) y luego cada hora. También con
// "qs ipc call updates refresh", que lanza update-reddots.sh al terminar.
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
                const list = kind => lines.filter(l => l.startsWith(kind + "|")).map(l => l.slice(kind.length + 1))
                root.repos = list("repos")
                root.aur = list("aur")
            }
        }
    }

    Timer {                             // Primera vez, un minuto después de arrancar
        interval: 60 * 1000
        running: true
        onTriggered: root.refresh()
    }

    Timer {                             // Y luego cada hora
        interval: 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "updates"

        function refresh(): void {
            root.refresh()
        }
    }
}
