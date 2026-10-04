pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.components

// Igual que Geometry.qml pero para propiedades que no vive Quickshell sino
// Hyprland (gaps, grosor de borde de ventana, redondeo, opacidad). Se aplican en
// caliente y se guardan para el siguiente arranque en ~/.config/hypr/shellOverrides.lua
// con components/HyprConfigFile.qml (ver allí cómo y por qué), lo mismo que los colores
// del tema en Theme.qml.
Singleton {
    id: root

    property alias gapsIn: adapter.gapsIn
    property alias gapsOut: adapter.gapsOut
    property alias borderSize: adapter.borderSize
    property alias rounding: adapter.rounding
    property alias windowOpacity: adapter.windowOpacity

    readonly property var editable: [     // Todas en la sección "Ventanas" del panel (ver "group" en Geometry.qml)
        { target: root, group: "Ventanas", key: "gapsIn",     label: "Espacio entre ventanas",   min: 0, max: 40, step: 1 },
        { target: root, group: "Ventanas", key: "gapsOut",    label: "Espacio con el borde",     min: 0, max: 60, step: 1 },
        { target: root, group: "Ventanas", key: "borderSize", label: "Grosor del borde",         min: 0, max: 10, step: 1 },
        { target: root, group: "Ventanas", key: "rounding",   label: "Redondeo",                 min: 0, max: 40, step: 1 },
        // Mínimo 10 %: por debajo las ventanas son prácticamente invisibles y
        // costaría encontrar el panel para volver a subirla
        { target: root, group: "Ventanas", key: "windowOpacity", label: "Opacidad",              min: 10, max: 100, step: 5, unit: "%" }
    ]

    // En el JSON va en % (entero, para que el stepper no acumule decimales);
    // Hyprland la quiere de 0 a 1. 90/100 se imprime "0.9", no 0.9000001.
    readonly property real opacity: windowOpacity / 100

    // Tablas de hl.config() para HyprConfigFile.qml. Se regenera todo cada vez (no un
    // patch incremental tipo regex): como solo hay unas pocas claves y se conocen
    // siempre, es más simple y no deja líneas huérfanas si algún día se quita una.
    function configText() {
        return "general = { gaps_in = " + root.gapsIn
             + ", gaps_out = " + root.gapsOut
             + ", border_size = " + root.borderSize
             + " }, decoration = { rounding = " + root.rounding
             + ", active_opacity = " + root.opacity                 // Las tres iguales, como el "local opacity" de hyprland.lua
             + ", inactive_opacity = " + root.opacity
             + ", fullscreen_opacity = " + root.opacity + " }"
    }

    function sync() { overridesFile.sync(root.configText()) }

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
            property int windowOpacity: 90 // hypr/hyprland.lua: "local opacity" (active/inactive/fullscreen_opacity), en %
        }
    }

    HyprConfigFile {
        id: overridesFile
        name: "shellOverrides"
        generator: "HyprGeometry.qml"
    }
}
