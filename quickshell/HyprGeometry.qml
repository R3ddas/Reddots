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

    // Redondeo de las ventanas: no se elige, se calcula para que sus esquinas sean
    // concéntricas con las del marco de Border.qml (mismo centro de curva), y así la
    // separación entre ventana y marco sea igual en los lados rectos que en la curva.
    // Con otro valor las esquinas se ven "desencajadas": más abiertas o más cerradas
    // en la diagonal que en los lados.
    //   radio exterior de la ventana = radio interior del marco − distancia entre ambos
    // donde, según cómo dibuja Hyprland:
    //   - radio exterior de la ventana = rounding + border_size (el borde va por fuera
    //     del contenido y su curva exterior es rounding + border_size)
    //   - distancia = gapsOut − borderThickness (gaps_out se mide desde el borde de la
    //     pantalla, o de la barra por la izquierda, igual que el marco, que ocupa los
    //     primeros borderThickness píxeles)
    // Despejando sale la fórmula de abajo. Solo encaja con rounding_power = 2 (esquinas
    // circulares, como las del marco; ver hypr/hyprland.lua). Si sale negativo (marco
    // poco redondeado para la distancia que hay), las ventanas van con esquinas rectas.
    readonly property int rounding: Math.max(0, Geometry.borderRounding - (gapsOut - Geometry.borderThickness) - borderSize)

    // Sin "rounding": se calcula solo (ver arriba), así que no sale en el panel
    readonly property var editable: [
        { target: root, key: "gapsIn",     label: "Espacio entre ventanas",        min: 0, max: 40, step: 1 },
        { target: root, key: "gapsOut",    label: "Espacio con borde de pantalla", min: 0, max: 60, step: 1 },
        { target: root, key: "borderSize", label: "Grosor borde de ventana",       min: 0, max: 10, step: 1 }
    ]

    // Regenera el archivo entero cada vez (no un patch incremental tipo
    // regex): como solo hay 4 claves (3 elegidas y el redondeo calculado) y las 4 se conocen siempre, es más
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
        if (!root.loaded) return            // Aún no se sabe lo guardado: se escribirían los valores por defecto y enseguida los de verdad
        const text = root.overridesText()
        if (overridesFile.text() === text) return
        overridesFile.setText(text)                                     // Para el siguiente arranque de Hyprland
        Quickshell.execDetached(["hyprctl", "eval", root.evalText()])   // En caliente
    }

    // Ya se ha leído hyprGeometry.json (o se sabe que no existe). Hasta entonces las medidas
    // valen las de por defecto y sync() no hace nada.
    property bool loaded: false

    // El redondeo también cambia al tocar el marco (Geometry.qml) o, sin pasar por
    // onAdapterUpdated, al cargar el JSON: en todos esos casos hay que aplicarlo
    onRoundingChanged: sync()

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
        onLoaded: {
            root.loaded = true
            root.sync()
        }
        onLoadFailed: root.loaded = true    // Aún no existe (instalación nueva): valen los de por defecto, y se escribe al primer cambio

        // Estos valores solo se usan la primerísima vez (si hyprGeometry.json
        // no existe todavía); a partir de ahí manda lo que haya en ese JSON.
        // Los puse iguales a los que hay ahora mismo en hyprland.lua para
        // que instalar esto no cambie nada a simple vista.
        JsonAdapter {
            id: adapter
            property int gapsIn: 5        // hypr/hyprland.lua: general.gaps_in
            property int gapsOut: 12      // hypr/hyprland.lua: general.gaps_out
            property int borderSize: 2    // hypr/hyprland.lua: general.border_size
        }
    }

    FileView {
        id: overridesFile
        path: Quickshell.env("HOME") + "/.config/hypr/shellOverrides.lua"
        atomicWrites: true
        blockLoading: true      // Para que text() devuelva ya el contenido actual al arrancar (igual que en Theme.qml)
    }
}

