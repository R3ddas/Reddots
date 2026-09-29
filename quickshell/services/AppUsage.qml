pragma Singleton
import Quickshell
import Quickshell.Io                // Para FileView y JsonAdapter
import QtQuick

// Cuántas veces se ha abierto cada aplicación desde el lanzador (Launcher.qml), para
// sacar primero las que más se usan. Se guarda en launcher.json (fuera del repo, junto
// a theme.json y wallpaper.json), así que sobrevive a reiniciar Quickshell.
// La clave es el id del .desktop ("code", "org.kde.kate"...), no el nombre que se ve:
// el nombre cambia con el idioma o al actualizar la app, el id no.
Singleton {
    id: root

    readonly property var counts: adapter.counts     // id -> veces que se ha abierto

    function count(entry) {
        return root.counts[entry.id] ?? 0
    }

    function record(entry) {
        // Objeto nuevo y no counts[id]++: si se cambia por dentro, QML no se entera
        // (ni se reordena la lista ni se guarda el archivo)
        const next = Object.assign({}, adapter.counts)
        next[entry.id] = (next[entry.id] ?? 0) + 1
        adapter.counts = next
    }

    FileView {
        path: Quickshell.statePath("launcher.json")
        watchChanges: true
        onFileChanged: reload()                         // Si se edita el JSON a mano, se recarga solo
        blockLoading: true                              // Es un archivo diminuto: así el primer orden ya lo tiene en cuenta
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter
            property var counts: ({})                   // Vacío hasta que se abre algo por primera vez
        }
    }
}
