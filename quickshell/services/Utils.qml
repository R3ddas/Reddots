pragma Singleton
import Quickshell
import QtQuick

// Funciones pequeñas que usan varios archivos y no tienen un sitio mejor.
Singleton {
    // Quita mayúsculas y tildes, para que "musica" encuentre "Música" (los buscadores de
    // Launcher.qml y Clipboard.qml)
    function normalize(s) {
        return (s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
    }

    // Salida de los scripts que escriben un dato por línea con la forma "tipo|valor"
    // (check-updates.sh, uninstall-check.sh, sensors.sh...): los valores de un tipo, en el
    // orden en que salen. "repos|vim 9.1 -> 9.2" con kind "repos" -> "vim 9.1 -> 9.2".
    function parseLines(text, kind) {
        return text.split("\n").filter(l => l.startsWith(kind + "|")).map(l => l.slice(kind.length + 1))
    }
}
