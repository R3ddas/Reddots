pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.components                // HyprConfigFile y StateFile

// Medidas de la interfaz, editables en caliente desde GeometrySettings.qml y guardadas en
// disco (fuera del repo, en el directorio de estado de Quickshell) para que sobrevivan a
// un reinicio. Hay dos tipos, y cada uno se guarda en su archivo:
//   - Las que vive Quickshell (barra lateral, borde de la pantalla, desplegables), en
//     geometry.json. Son bindings QML normales: efecto inmediato. Así Border.qml, Bar.qml
//     y los desplegables no repiten los mismos números ni se desincronizan entre sí.
//   - Las que vive Hyprland (gaps, borde, redondeo y opacidad de las ventanas), en
//     hyprGeometry.json. No hay binding posible con el compositor: cada cambio se aplica en
//     caliente y se guarda para el siguiente arranque en ~/.config/hypr/shellOverrides.lua,
//     con components/HyprConfigFile.qml (ver allí cómo y por qué), lo mismo que los
//     colores del tema en Theme.qml.
Singleton {
    id: root

    // --- Las que vive Quickshell ---
    property alias sidebarWidth: adapter.sidebarWidth
    property alias borderThickness: adapter.borderThickness
    property alias borderRounding: adapter.borderRounding
    property alias borderShadow: adapter.borderShadow
    property alias borderShadowOpacity: adapter.borderShadowOpacity
    property alias popupRounding: adapter.popupRounding
    property alias popupBorderWidth: adapter.popupBorderWidth

    // --- Las que vive Hyprland ---
    property alias gapsIn: hyprAdapter.gapsIn
    property alias gapsOut: hyprAdapter.gapsOut
    property alias borderSize: hyprAdapter.borderSize
    property alias rounding: hyprAdapter.rounding
    property alias windowOpacity: hyprAdapter.windowOpacity

    // Registro de propiedades editables: GeometrySettings.qml construye su panel
    // iterando esta lista, así que añadir aquí una entrada es lo único que hace falta para
    // que aparezca un nuevo control en el panel. "key" es el nombre de la propiedad de
    // este singleton. "group" es la sección del panel en la que sale (las secciones van
    // en el orden en que aparecen aquí; con un nombre nuevo, sale una sección nueva).
    // "unit" es opcional: lo que se muestra tras el número (si falta, "px").
    readonly property var editable: [
        { group: "Barra lateral",        key: "sidebarWidth",        label: "Ancho",                  min: 16, max: 80,  step: 1 },
        { group: "Borde de la pantalla", key: "borderThickness",     label: "Grosor",                 min: 0,  max: 20,  step: 1 },
        { group: "Borde de la pantalla", key: "borderRounding",      label: "Redondeo de esquinas",   min: 0,  max: 40,  step: 1 },
        { group: "Borde de la pantalla", key: "borderShadow",        label: "Sombra",                 min: 0,  max: 40,  step: 1 },
        { group: "Borde de la pantalla", key: "borderShadowOpacity", label: "Opacidad de la sombra",  min: 0,  max: 100, step: 5, unit: "%" },
        { group: "Desplegables",         key: "popupRounding",       label: "Redondeo",               min: 0,  max: 40,  step: 1 },
        { group: "Desplegables",         key: "popupBorderWidth",    label: "Grosor del borde",       min: 0,  max: 10,  step: 1 },
        { group: "Ventanas",             key: "gapsIn",              label: "Espacio entre ventanas", min: 0,  max: 40,  step: 1 },
        { group: "Ventanas",             key: "gapsOut",             label: "Espacio con el borde",   min: 0,  max: 60,  step: 1 },
        { group: "Ventanas",             key: "borderSize",          label: "Grosor del borde",       min: 0,  max: 10,  step: 1 },
        { group: "Ventanas",             key: "rounding",            label: "Redondeo",               min: 0,  max: 40,  step: 1 },
        // Mínimo 10 %: por debajo las ventanas son prácticamente invisibles y
        // costaría encontrar el panel para volver a subirla
        { group: "Ventanas",             key: "windowOpacity",       label: "Opacidad",               min: 10, max: 100, step: 5, unit: "%" }
    ]

    // "anchor.rect.y" (relativo a "item") para un popup de altura "popupHeight"
    // que se abre a la derecha de "item": centrado en vertical con el icono,
    // salvo que se saliese por abajo o por arriba, en cuyo caso se mueve lo
    // justo para que quede tan separado de ese borde como lo está del marco
    // por la izquierda. Se llama desde el "anchoring" de BarPopup.qml
    // (justo antes de colocarlo), porque mapToItem no avisa cuando el icono
    // cambia de sitio.
    function popupY(item, popupX, popupHeight) {
        const pos = item.mapToItem(null, 0, 0)                                     // Posición del icono dentro de la barra
        let win = item
        while (win.parent) win = win.parent                                        // contentItem de la barra: mide lo que la pantalla
        const leftGap = Math.max(0, pos.x + popupX - root.sidebarWidth - root.borderThickness)  // Hueco entre el marco izquierdo y el popup
        const maxY = win.height - root.borderThickness - leftGap - pos.y - popupHeight          // Lo más abajo que puede empezar
        const minY = root.borderThickness + leftGap - pos.y                                     // Lo más arriba que puede empezar
        const centered = (item.height - popupHeight) / 2                                        // Centrado con el icono
        return Math.max(minY, Math.min(centered, maxY))
    }

    StateFile {
        name: "geometry.json"

        JsonAdapter {
            id: adapter
            property int sidebarWidth: 32      // Ancho de la barra lateral (PanelWindow.implicitWidth y Border.margins.left deben coincidir)
            property int borderThickness: 6    // Grosor del marco que dibuja Border
            property int borderRounding: 22    // Radio de las esquinas redondeadas de Border
            property int borderShadow: 5       // Cuántos px hacia adentro se difumina la sombra de Border (0 = sin sombra)
            property int borderShadowOpacity: 80  // Opacidad máxima de esa sombra, en % (entero para que el stepper del panel sume/reste sin decimales sueltos)
            property int popupRounding: 16     // Radio de las esquinas de los desplegables de la barra
            property int popupBorderWidth: 2   // Grosor del borde de color de los desplegables y del lanzador (0 = sin borde)
        }
    }

    // --- Lo que se le pasa a Hyprland ---

    // En el JSON va en % (entero, para que el stepper no acumule decimales);
    // Hyprland la quiere de 0 a 1. 90/100 se imprime "0.9", no 0.9000001.
    readonly property real opacity: windowOpacity / 100

    // Tablas de hl.config() para HyprConfigFile.qml. Se regenera todo cada vez (no un
    // patch incremental tipo regex): como solo hay unas pocas claves y se conocen
    // siempre, es más simple y no deja líneas huérfanas si algún día se quita una.
    function hyprConfigText() {
        return "general = { gaps_in = " + root.gapsIn
             + ", gaps_out = " + root.gapsOut
             + ", border_size = " + root.borderSize
             + " }, decoration = { rounding = " + root.rounding
             + ", active_opacity = " + root.opacity                 // Las tres iguales, como el "local opacity" de hyprland.lua
             + ", inactive_opacity = " + root.opacity
             + ", fullscreen_opacity = " + root.opacity + " }"
    }

    function syncHyprland() { overridesFile.sync(root.hyprConfigText()) }

    StateFile {
        name: "hyprGeometry.json"
        onAdapterUpdated: root.syncHyprland()       // Además de guardarlo (eso ya lo hace StateFile)
        // Al arrancar Quickshell, onAdapterUpdated no se dispara solo por
        // cargar el JSON existente, así que se sincroniza una vez aquí por si
        // shellOverrides.lua se quedó desfasado (p.ej. se editó el JSON a mano
        // con Quickshell cerrado). Si coincide, no hace nada.
        onLoaded: root.syncHyprland()

        // Estos valores solo se usan la primerísima vez (si hyprGeometry.json
        // no existe todavía); a partir de ahí manda lo que haya en ese JSON.
        // Son los mismos que los de arranque de hyprland.lua, para que
        // instalar esto no cambie nada a simple vista.
        JsonAdapter {
            id: hyprAdapter
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
        generator: "Geometry.qml"
    }
}
