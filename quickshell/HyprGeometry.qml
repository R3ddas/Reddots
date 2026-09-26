pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Igual que Geometry.qml pero para propiedades que no vive Quickshell sino
// Hyprland (gaps, grosor de borde de ventana, redondeo). No hay binding
// directo posible con el compositor, así que cada cambio se hace en dos sitios:
//   - En caliente, con "hyprctl eval" de la misma llamada a hl.config().
//   - Para el siguiente arranque, en ~/.config/hypr/shellOverrides.lua (fuera
//     del repo, generado por este archivo, igual que geometry.json).
//     hyprland.lua hace require() de ese archivo si existe, y como es una
//     llamada a hl.config() con solo estas claves, no toca el resto de
//     opciones de general/decoration.
// No se usa "hyprctl reload": recargaría todo hyprland.lua y desharía lo que
// se ha cambiado en caliente desde fuera (el panel del portátil apagado por
// hypr/scripts/lid-watcher.sh, el mirror de Super+M...).
Singleton {
    id: root

    property alias gapsIn: adapter.gapsIn
    property alias gapsOut: adapter.gapsOut
    property alias borderSize: adapter.borderSize
    property alias rounding: adapter.rounding

    readonly property var editable: [
        { target: root, key: "gapsIn",     label: "Espacio entre ventanas",        min: 0, max: 40, step: 1 },
        { target: root, key: "gapsOut",    label: "Espacio con borde de pantalla", min: 0, max: 60, step: 1 },
        { target: root, key: "borderSize", label: "Grosor borde de ventana",       min: 0, max: 10, step: 1 },
        { target: root, key: "rounding",   label: "Redondeo de ventanas",          min: 0, max: 40, step: 1 }
    ]

    // Regenera el archivo entero cada vez (no un patch incremental tipo
    // regex): como solo hay 4 claves y las 4 se conocen siempre, es más
    // simple y evita el riesgo de dejar líneas huérfanas si algún día se
    // quita una clave de aquí.
    function overridesText() {
        return "-- Generado por HyprGeometry.qml (quickshell). No editar a mano: se sobrescribe.\n"
             + "hl.config({\n"
             + "    general = {\n"
             + "        gaps_in = " + root.gapsIn + ",\n"
             + "        gaps_out = " + root.gapsOut + ",\n"
             + "        border_size = " + root.borderSize + ",\n"
             + "    },\n"
             + "    decoration = {\n"
             + "        rounding = " + root.rounding + ",\n"
             + "    },\n"
             + "})\n"
    }

    // Lo mismo que el archivo pero en una línea, para "hyprctl eval"
    function evalText() {
        return "hl.config({ general = { gaps_in = " + root.gapsIn
             + ", gaps_out = " + root.gapsOut
             + ", border_size = " + root.borderSize
             + " }, decoration = { rounding = " + root.rounding + " } })"
    }

    // Si shellOverrides.lua ya tiene estos valores no se hace nada: es lo que
    // pasa en casi todos los arranques de Quickshell, y Hyprland ya los cargó
    // con el require().
    function sync() {
        const text = root.overridesText()
        if (overridesFile.text() === text) return
        overridesFile.setText(text)                                     // Para el siguiente arranque de Hyprland
        Quickshell.execDetached(["hyprctl", "eval", root.evalText()])   // En caliente
    }

    FileView {
        path: Quickshell.statePath("hyprGeometry.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: {
            writeAdapter()
            root.sync()
        }
        // Al arrancar Quickshell, onAdapterUpdated no se dispara solo por
        // cargar el JSON existente, así que se sincroniza una vez aquí por si
        // shellOverrides.lua se quedó desfasado (p.ej. se editó el JSON a mano
        // con Quickshell cerrado). Si coincide, sync() no hace nada.
        onLoaded: root.sync()

        // Estos valores solo se usan la primerísima vez (si hyprGeometry.json
        // no existe todavía); a partir de ahí manda lo que haya en ese JSON.
        // Los puse iguales a los que hay ahora mismo en hyprland.lua para
        // que instalar esto no cambie nada a simple vista.
        JsonAdapter {
            id: adapter
            property int gapsIn: 5        // hypr/hyprland.lua: general.gaps_in
            property int gapsOut: 12      // hypr/hyprland.lua: general.gaps_out
            property int borderSize: 2    // hypr/hyprland.lua: general.border_size
            property int rounding: 16     // hypr/hyprland.lua: decoration.rounding
        }
    }

    FileView {
        id: overridesFile
        path: Quickshell.env("HOME") + "/.config/hypr/shellOverrides.lua"
        atomicWrites: true
        blockLoading: true      // Para que text() devuelva ya el contenido actual al arrancar (igual que en Theme.qml)
    }
}

