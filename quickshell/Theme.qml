pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Temas de color en formato Base16 (https://github.com/tinted-theming/home): cada tema son
// 16 colores en un orden fijo, así que un tema nuevo se añade copiando los 16 de su esquema
// (hay cientos en https://github.com/tinted-theming/schemes, carpeta base16):
//   base00–base07: del fondo al texto. 00 fondo, 01 fondo más claro (desplegables),
//                  02 selección y bordes, 03 comentarios, 04 texto apagado, 05 texto,
//                  06–07 texto más claro (en los temas claros, más oscuro)
//   base08–base0F: rojo, naranja, amarillo, verde, cian, azul, morado y marrón
// Cada tema dice además qué casilla hace de color de acento ("accent").
//
// La barra no usa las casillas directamente sino los "papeles" de roles(): background,
// textActive, textSelected (el acento)... Alacritty sí recibe los 16 (ver syncAlacritty()).
//
// De dónde sale cada tema (lo dice el comentario de su línea):
//   - "Base16: <nombre>": el esquema de tinted-theming tal cual.
//   - "reordenados": GitHub y Tokyo Night tienen en su esquema Base16 los acentos fuera de
//     sitio (el rojo en la casilla del morado...): son sus colores oficiales, cada uno en su casilla.
//   - Everblush, Nightfox y Sonokai no tienen esquema Base16: salen de sus paletas oficiales.
//   - Old World, Shado Theme, Dark Green y Caelestia son esquemas Material de Caelestia
//     (https://github.com/caelestia-dots/cli/tree/main/src/caelestia/data/schemes), en los que
//     todos los colores son tonos del principal: los grises, el principal y el rojo (su color
//     de error) son suyos; los demás acentos se han generado a juego (misma luminosidad y
//     saturación, cada uno con su tono), para que en la terminal el verde sea verde.
//   - Original: hecho a mano, con el mismo criterio para los acentos que le faltaban.

Singleton {
    // Tema activo: se elige desde el icono de la paleta en la barra
    // (ThemeSettings.qml) y se guarda solo, gracias al FileView de más abajo.
    // El de por defecto (instalación nueva) es el del JsonAdapter, "Gruvbox Claro";
    // si lo cambias, cambia también los colores de arranque de col en hypr/hyprland.lua.
    // Debe coincidir con el "name" de uno de los temas de "themes".
    property alias activeTheme: adapter.activeTheme

    FileView {
        path: Quickshell.statePath("theme.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: syncAll()             // Al arrancar, cuando ya se sabe el tema guardado (antes activeTheme aún vale el de por defecto)
        onLoadFailed: syncAll()         // Si theme.json aún no existe (instalación nueva), con el tema por defecto

        JsonAdapter {
            id: adapter
            property string activeTheme: "Gruvbox Claro"
        }
    }

    function themeByName(themeName) {
        for (var i = 0; i < themes.length; i++) {
            if (themes[i].name === themeName)
                return themes[i]
        }
        return themes[0]
    }

    // Cada tema: nombre, casilla del acento y sus 16 colores (base00–07 en la primera
    // línea, base08–0F en la segunda). El orden de aquí es el del selector de la barra.
    readonly property var themes: [
        { name: "Original", accent: "base09",     // hecho a mano: grises y rojo/naranja/verde/azul propios, el resto a juego
          base: ["#454138", "#454138", "#5a4d3e", "#837564", "#a8957c", "#f5e2c5", "#f5e2c5", "#f5e2c5",
                 "#c1502e", "#db911a", "#9e8934", "#7c8b53", "#079e9e", "#6f8fa3", "#a774b2", "#964f2c"] },
        { name: "Gruvbox Claro", accent: "base09",     // Base16: gruvbox-light
          base: ["#fbf1c7", "#ebdbb2", "#d5c4a1", "#bdae93", "#7c6f64", "#3c3836", "#282828", "#1d2021",
                 "#cc241d", "#d65d0e", "#d79921", "#98971a", "#689d6a", "#458588", "#b16286", "#9d0006"] },
        { name: "Gruvbox Oscuro", accent: "base09",     // Base16: gruvbox-dark
          base: ["#282828", "#3c3836", "#504945", "#665c54", "#928374", "#ebdbb2", "#fbf1c7", "#f9f5d7",
                 "#cc241d", "#d65d0e", "#d79921", "#98971a", "#689d6a", "#458588", "#b16286", "#9d0006"] },
        { name: "Everforest Claro", accent: "base09",     // Base16: everforest-light-medium
          base: ["#fdf6e3", "#f4f0d9", "#e6e2cc", "#939f91", "#829181", "#5c6a72", "#475258", "#2d353b",
                 "#f85552", "#f57d26", "#dfa000", "#8da101", "#35a77c", "#3a94c5", "#df69ba", "#829181"] },
        { name: "Everforest Oscuro", accent: "base09",     // Base16: everforest
          base: ["#2d353b", "#343f44", "#475258", "#859289", "#9da9a0", "#d3c6aa", "#e6e2cc", "#fdf6e3",
                 "#e67e80", "#e69875", "#dbbc7f", "#a7c080", "#83c092", "#7fbbb3", "#d699b6", "#9da9a0"] },
        { name: "Rosé Pine Claro", accent: "base08",     // Base16: rose-pine-dawn
          base: ["#faf4ed", "#fffaf3", "#f2e9de", "#9893a5", "#797593", "#575279", "#575279", "#cecacd",
                 "#b4637a", "#ea9d34", "#d7827e", "#286983", "#56949f", "#907aa9", "#ea9d34", "#cecacd"] },
        { name: "Rosé Pine Oscuro", accent: "base08",     // Base16: rose-pine
          base: ["#191724", "#1f1d2e", "#26233a", "#6e6a86", "#908caa", "#e0def4", "#e0def4", "#524f67",
                 "#eb6f92", "#f6c177", "#ebbcba", "#31748f", "#9ccfd8", "#c4a7e7", "#f6c177", "#524f67"] },
        { name: "Catppuccin Claro", accent: "base08",     // Base16: catppuccin-latte
          base: ["#eff1f5", "#e6e9ef", "#ccd0da", "#bcc0cc", "#acb0be", "#4c4f69", "#dc8a78", "#7287fd",
                 "#d20f39", "#fe640b", "#df8e1d", "#40a02b", "#179299", "#1e66f5", "#8839ef", "#dd7878"] },
        { name: "Catppuccin Oscuro", accent: "base08",     // Base16: catppuccin-mocha
          base: ["#1e1e2e", "#181825", "#313244", "#45475a", "#585b70", "#cdd6f4", "#f5e0dc", "#b4befe",
                 "#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#94e2d5", "#89b4fa", "#cba6f7", "#f2cdcd"] },
        { name: "Nord Oscuro", accent: "base0C",     // Base16: nord
          base: ["#2e3440", "#3b4252", "#434c5e", "#4c566a", "#d8dee9", "#e5e9f0", "#eceff4", "#8fbcbb",
                 "#bf616a", "#d08770", "#ebcb8b", "#a3be8c", "#88c0d0", "#81a1c1", "#b48ead", "#5e81ac"] },
        { name: "Dracula Oscuro", accent: "base0D",     // Base16: dracula
          base: ["#282a36", "#21222c", "#44475a", "#6272a4", "#9ea8c7", "#f8f8f2", "#f8f8f2", "#ffffff",
                 "#ff5555", "#ffb86c", "#f1fa8c", "#50fa7b", "#8be9fd", "#bd93f9", "#ff79c6", "#993333"] },
        { name: "Solarized Claro", accent: "base0D",     // Base16: solarized-light
          base: ["#fdf6e3", "#eee8d5", "#93a1a1", "#839496", "#657b83", "#586e75", "#073642", "#002b36",
                 "#dc322f", "#cb4b16", "#b58900", "#859900", "#2aa198", "#268bd2", "#6c71c4", "#d33682"] },
        { name: "Solarized Oscuro", accent: "base0D",     // Base16: solarized-dark
          base: ["#002b36", "#073642", "#586e75", "#657b83", "#839496", "#93a1a1", "#eee8d5", "#fdf6e3",
                 "#dc322f", "#cb4b16", "#b58900", "#859900", "#2aa198", "#268bd2", "#6c71c4", "#d33682"] },
        { name: "Tokyo Night Oscuro", accent: "base0D",     // tokyo-night-dark (acentos reordenados)
          base: ["#1a1b26", "#16161e", "#2f3549", "#444b6a", "#787c99", "#a9b1d6", "#cbccd1", "#d5d6db",
                 "#f7768e", "#ff9e64", "#e0af68", "#9ece6a", "#7dcfff", "#7aa2f7", "#bb9af7", "#d18616"] },
        { name: "One Dark Oscuro", accent: "base0D",     // Base16: onedark
          base: ["#282c34", "#353b45", "#3e4451", "#545862", "#565c64", "#abb2bf", "#b6bdca", "#c8ccd4",
                 "#e06c75", "#d19a66", "#e5c07b", "#98c379", "#56b6c2", "#61afef", "#c678dd", "#be5046"] },
        { name: "Everblush Oscuro", accent: "base0B",     // everblush (Caelestia)
          base: ["#141b1e", "#232a2d", "#3a4145", "#8a8f94", "#b3b9be", "#e8e8e8", "#e8e8e8", "#e8e8e8",
                 "#e57474", "#e59a84", "#e5c76b", "#8ccfb0", "#6cbfbf", "#67b0e8", "#c47fd5", "#e5a5c5"] },
        { name: "Old World Oscuro", accent: "base0D",     // oldworld (Caelestia; acentos a juego)
          base: ["#121317", "#1e2023", "#43474f", "#8e909a", "#c4c6d0", "#e3e2e7", "#e3e2e7", "#ffffff",
                 "#ffb4ab", "#f5ba92", "#dac886", "#a5d8a6", "#80dada", "#aac7ff", "#e2b6ec", "#c18367"] },
        { name: "Shado Theme Oscuro", accent: "base0D",     // shadotheme (Caelestia; acentos a juego)
          base: ["#131317", "#1f1f23", "#46464f", "#918f9a", "#c7c5d1", "#e5e1e7", "#e5e1e7", "#ffffff",
                 "#ffb4ab", "#f6ba92", "#dac986", "#a5d8a6", "#7fdbda", "#bfc1ff", "#e3b7ed", "#c28367"] },
        { name: "Dark Green Oscuro", accent: "base0B",     // darkgreen (Caelestia; acentos a juego)
          base: ["#23262d", "#23262c", "#343434", "#979797", "#c9c9c9", "#f5f5f6", "#f5f5f6", "#ffffff",
                 "#c66e73", "#d9792b", "#af9314", "#24bd5c", "#02abab", "#5197ee", "#bd75cd", "#b04a0d"] },
        { name: "Caelestia Claro", accent: "base0C",     // caelestia (Caelestia; acentos a juego)
          base: ["#f6faf9", "#e7f0ee", "#a9b4b3", "#727d7c", "#566160", "#2a3433", "#2a3433", "#0a0f0f",
                 "#a83836", "#8f4d15", "#725f03", "#327036", "#1c6a66", "#31619e", "#7c4a87", "#732d02"] },
        { name: "Caelestia Oscuro", accent: "base0C",     // caelestia (Caelestia; acentos a juego)
          base: ["#0a0f0f", "#131b1a", "#3f4a49", "#6d7876", "#a2adac", "#dce8e6", "#dce8e6", "#f6faf9",
                 "#fa746f", "#eaa16e", "#cab35c", "#86c788", "#9bd0cc", "#83b7f9", "#d39ddf", "#bb6e4a"] },
        { name: "Monokai Oscuro", accent: "base0B",     // Base16: monokai
          base: ["#272822", "#383830", "#49483e", "#75715e", "#a59f85", "#f8f8f2", "#f5f4f1", "#f9f8f5",
                 "#f92672", "#fd971f", "#f4bf75", "#a6e22e", "#a1efe4", "#66d9ef", "#ae81ff", "#cc6633"] },
        { name: "Kanagawa Oscuro", accent: "base0D",     // Base16: kanagawa
          base: ["#1f1f28", "#16161d", "#223249", "#54546d", "#727169", "#dcd7ba", "#c8c093", "#717c7c",
                 "#c34043", "#ffa066", "#c0a36e", "#76946a", "#6a9589", "#7e9cd8", "#957fb8", "#d27e99"] },
        { name: "Ayu Claro", accent: "base09",     // Base16: ayu-light
          base: ["#f8f9fa", "#edeff1", "#d2d4d8", "#a0a6ac", "#8a9199", "#5c6166", "#4e5257", "#404447",
                 "#f07171", "#fa8d3e", "#f2ae49", "#6cbf49", "#4cbf99", "#399ee6", "#a37acc", "#e6ba7e"] },
        { name: "Ayu Mirage", accent: "base0A",     // Base16: ayu-mirage
          base: ["#1f2430", "#242936", "#323844", "#4a5059", "#707a8c", "#cccac2", "#d9d7ce", "#f3f4f5",
                 "#f28779", "#ffad66", "#ffd173", "#d5ff80", "#95e6cb", "#73d0ff", "#d4bfff", "#f27983"] },
        { name: "Ayu Oscuro", accent: "base0F",     // Base16: ayu-dark
          base: ["#0b0e14", "#131721", "#202229", "#3e4b59", "#bfbdb6", "#e6e1cf", "#ece8db", "#f2f0e7",
                 "#f07178", "#ff8f40", "#ffb454", "#aad94c", "#95e6cb", "#59c2ff", "#d2a6ff", "#e6b450"] },
        { name: "Nightfox Claro", accent: "base08",     // dayfox (nightfox.nvim)
          base: ["#f6f2ee", "#e4dcd4", "#dbd1dd", "#837a72", "#643f61", "#3d2b5a", "#302b5d", "#352c24",
                 "#a5222f", "#955f61", "#ac5402", "#396847", "#287980", "#2848a9", "#6e33ce", "#a440b5"] },
        { name: "Nightfox Oscuro", accent: "base0D",     // nightfox (nightfox.nvim)
          base: ["#192330", "#212e3f", "#29394f", "#738091", "#aeafb0", "#cdcecf", "#d6d6d7", "#dfdfe0",
                 "#c94f6d", "#f4a261", "#dbc074", "#81b29a", "#63cdcf", "#719cd6", "#9d79d6", "#d67ad2"] },
        { name: "Oxocarbon Claro", accent: "base0D",     // Base16: oxocarbon-light
          base: ["#f2f4f8", "#dde1e6", "#bec6cf", "#a1acba", "#68788d", "#525f70", "#3d4652", "#272d35",
                 "#ff7eb6", "#ee5396", "#ff6f00", "#42be65", "#673ab7", "#0f62fe", "#be95ff", "#803800"] },
        { name: "Oxocarbon Oscuro", accent: "base0D",     // Base16: oxocarbon-dark
          base: ["#161616", "#262626", "#393939", "#525252", "#dde1e6", "#f2f4f8", "#ffffff", "#08bdba",
                 "#ee5396", "#ff7eb6", "#ff6f00", "#42be65", "#3ddbd9", "#33b1ff", "#be95ff", "#82cfff"] },
        { name: "GitHub Claro", accent: "base0D",     // github (acentos reordenados)
          base: ["#ffffff", "#f6f8fa", "#afb8c1", "#8c959f", "#6e7781", "#424a53", "#32383f", "#1f2328",
                 "#cf222e", "#953800", "#bf8700", "#116329", "#0a3069", "#0550ae", "#8250df", "#82071e"] },
        { name: "GitHub Oscuro", accent: "base0D",     // github-dark (acentos reordenados)
          base: ["#0d1117", "#161b22", "#484f58", "#6e7681", "#8b949e", "#c9d1d9", "#f0f6fc", "#ffffff",
                 "#ff7b72", "#ffa657", "#bb8009", "#7ee787", "#a5d6ff", "#79c0ff", "#d2a8ff", "#ffa198"] },
        { name: "Zenburn Oscuro", accent: "base0C",     // Base16: zenburn
          base: ["#383838", "#404040", "#606060", "#6f6f6f", "#808080", "#dcdccc", "#c0c0c0", "#ffffff",
                 "#dca3a3", "#dfaf8f", "#e0cf9f", "#5f7f5f", "#93e0e3", "#7cb8bb", "#dc8cc3", "#000000"] },
        { name: "Sonokai Oscuro", accent: "base08",     // Base16: sonokai
          base: ["#2c2e34", "#33353f", "#414550", "#595f6f", "#7f8490", "#e2e2e3", "#e2e2e3", "#e2e2e3",
                 "#fc5d7c", "#f39660", "#e7c664", "#9ed072", "#76cce0", "#85d3f2", "#b39df3", "#ff6077"] },
        { name: "Horizon Oscuro", accent: "base08",     // Base16: horizon-terminal-dark
          base: ["#1c1e26", "#232530", "#2e303e", "#6f6f70", "#9da0a2", "#cbced0", "#dcdfe4", "#e3e6ee",
                 "#e95678", "#fab795", "#fac29a", "#29d398", "#59e1e3", "#26bbd9", "#ee64ac", "#f09383"] }
    ]

    // Papeles de la barra a partir de los 16 colores de un tema
    function roles(theme) {
        const b = theme.base
        // Texto apagado (workspaces vacíos, pistas...): base03 o base04, el que mejor se
        // distinga a la vez del fondo y del texto normal (según el tema, uno de los dos se
        // confunde con el fondo o con el texto)
        const mutedScore = c => Math.min(contrast(c, b[0]), contrast(b[5], c))
        return {
            background:   b[0],     // La barra lateral y el recuadro
            surface:      b[1],     // Fondo de los desplegables y ventanas flotantes
            // Fila bajo el ratón: base02, salvo que el texto no se lea encima (Solarized);
            // entonces un velo del color del texto sobre el fondo del desplegable
            surfaceHover: contrast(b[5], b[2]) >= 3 ? b[2] : Qt.tint(b[1], Qt.alpha(b[5], 0.12)),
            border:       b[2],     // Bordes y separadores
            textActive:   b[5],     // Texto normal
            textDisabled: mutedScore(b[4]) > mutedScore(b[3]) ? b[4] : b[3],
            textSelected: b[parseInt(theme.accent.slice(4), 16)]   // Acento: "base0D" -> casilla 13
        }
    }

    // Luminancia relativa (WCAG) de un color "#rrggbb": 0 = negro, 1 = blanco
    function luminance(hex) {
        const c = [1, 3, 5].map(i => parseInt(hex.substr(i, 2), 16) / 255)
                           .map(v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4))
        return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    }

    // Contraste WCAG entre dos colores: de 1 (iguales) a 21 (blanco y negro)
    function contrast(a, b) {
        const la = luminance(a), lb = luminance(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }

    // Tema claro (fondo claro) u oscuro, según la luminancia de base00. El mismo
    // criterio que usa scripts/gen-alacritty-colors.py; lo usa el selector (ThemeSettings.qml)
    function isLight(theme) {
        return luminance(theme.base[0]) > 0.18
    }

    readonly property var current: roles(themeByName(activeTheme))
    readonly property var base:    themeByName(activeTheme).base   // Los 16 colores del tema activo, por si algún widget necesita un rojo, un verde...

    readonly property color background:   current.background
    readonly property color textActive:   current.textActive
    readonly property color textSelected: current.textSelected
    readonly property color textDisabled: current.textDisabled
    readonly property color surface:      current.surface
    readonly property color surfaceHover: current.surfaceHover
    readonly property color border:       current.border

    // Alacritty es un proceso aparte y no puede leer este QML directamente,
    // así que le regeneramos su colors.toml (ver alacritty/alacritty.toml,
    // que lo importa) cada vez que cambia el tema. Alacritty recarga solo
    // porque tiene live_config_reload activado por defecto.
    Process { id: alacrittySync }       // El comando se pone en syncAlacritty(), justo antes de lanzarlo

    property string alacrittyTheme: ""  // Último tema enviado a Alacritty: al arrancar el tema llega por onLoaded y por onActiveThemeChanged, así no se genera dos veces

    function syncAlacritty() {
        if (alacrittyTheme === activeTheme) return
        alacrittyTheme = activeTheme
        const t = themeByName(activeTheme)  // Directo del tema, no de las propiedades derivadas (lo mismo que en hyprGeneralText())
        alacrittySync.running = false
        alacrittySync.command = [Quickshell.shellPath("scripts/gen-alacritty-colors.py")].concat(t.base)   // Los 16 colores, base00 … base0F
        alacrittySync.running = true
    }

    // Lo mismo para los bordes de las ventanas, que los pinta Hyprland: igual
    // que HyprGeometry.qml con las medidas, se aplican en caliente con
    // "hyprctl eval" y se regenera entero ~/.config/hypr/shellTheme.lua (fuera
    // del repo) para el siguiente arranque. hyprland.lua hace require() de ese
    // archivo si existe. Sin "hyprctl reload", por lo mismo que en HyprGeometry.qml:
    // desharía el panel apagado por lid-watcher.sh, el mirror de Super+M...
    function hyprColor(c, alpha) {
        return "0x" + alpha + c.toString().slice(1)     // "#rrggbb" -> 0xAARRGGBB, el formato de hyprland.lua
    }

    // Tabla "general = {...}" que se pasa a hl.config(), en una línea (vale tanto para el archivo como para "hyprctl eval")
    function hyprGeneralText() {
        const t = roles(themeByName(activeTheme))       // Directo del tema, no de las propiedades derivadas: puede que aún no se hayan actualizado al saltar onActiveThemeChanged
        return "general = { col = { "
             + "active_border = { colors = {" + hyprColor(t.textSelected, "ee") + ", " + hyprColor(t.textActive, "ee") + "}, angle = 45 }, "  // Degradado, como el que había fijo en hyprland.lua
             + "inactive_border = " + hyprColor(t.border, "aa")
             + " } }"
    }

    function hyprThemeText() {
        return "-- Generado por Theme.qml (quickshell). No editar a mano: se sobrescribe.\n"
             + "hl.config({ " + hyprGeneralText() + " })\n"
    }

    FileView {
        id: hyprThemeFile
        path: Quickshell.env("HOME") + "/.config/hypr/shellTheme.lua"
        atomicWrites: true
        blockLoading: true                                  // Para que text() devuelva ya el contenido actual al arrancar
    }

    function syncHyprland() {
        const text = hyprThemeText()
        if (hyprThemeFile.text() === text) return           // Si no ha cambiado nada no se toca (lo normal en cada arranque de Quickshell: Hyprland ya lo cargó con el require())
        hyprThemeFile.setText(text)                                                             // Para el siguiente arranque de Hyprland
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ " + hyprGeneralText() + " })"])  // En caliente
    }

    function syncAll() {
        syncAlacritty()
        syncHyprland()
    }

    onActiveThemeChanged: syncAll()
}
