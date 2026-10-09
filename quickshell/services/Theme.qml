pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.components                // HyprConfigFile y StateFile
import "themes.js" as Themes        // La lista de temas

// Tema de color activo y lo que sale de él: los colores de la barra, los de Alacritty y los
// de los bordes de Hyprland. Los temas (en formato Base16: 16 colores en un orden fijo) están
// en themes.js, en esta misma carpeta: ver allí qué es cada color y cómo se añade un tema.
//
// La barra no usa las casillas directamente sino los "papeles" de roles(): background,
// textActive, textSelected (el acento)... Alacritty sí recibe los 16 (ver alacrittyText()).

Singleton {
    id: root

    // Tema por defecto, el mismo en los dos casos en que hace falta uno: en una instalación
    // nueva (aún no hay theme.json) y si el tema guardado ya no existe (p.ej. uno que se ha
    // quitado de la lista). Debe coincidir con el "name" de uno de los temas de "themes".
    // Si lo cambias, cambia también el activeTheme del JsonAdapter (más abajo) y los colores
    // de arranque de hypr/hyprland.lua (col y background_color), que son los suyos.
    readonly property string defaultTheme: "Original"

    // Tema activo: se elige desde el icono de la paleta en la barra
    // (ThemeSettings.qml) y se guarda solo, gracias al StateFile de más abajo.
    property alias activeTheme: adapter.activeTheme

    StateFile {
        name: "theme.json"
        onLoaded: syncAll()             // Al arrancar, cuando ya se sabe el tema guardado (antes activeTheme aún vale el de por defecto)
        onLoadFailed: syncAll()         // Si theme.json aún no existe (instalación nueva), con el tema por defecto

        JsonAdapter {
            id: adapter
            // El mismo que defaultTheme, pero escrito tal cual y no "root.defaultTheme": con un
            // binding, al crearse avisaba de un cambio de tema (onActiveThemeChanged) antes de
            // leer theme.json y aplicaba este a Alacritty y a Hyprland. El tema guardado, que
            // llega justo después, a veces no se escribía: el FileView aún devolvía en text() lo
            // que había antes en el archivo, y parecía que ya estaba puesto
            property string activeTheme: "Original"
        }
    }

    function themeByName(themeName) {
        return themes.find(t => t.name === themeName)
            ?? themes.find(t => t.name === root.defaultTheme)          // Si no existe (p.ej. un tema que se ha quitado), el de por defecto
    }

    // Todos los temas: los de aquí y, si ya se ha creado, el sacado del fondo de pantalla
    // (al final de la lista)
    readonly property var themes: WallpaperTheme.theme ? presetThemes.concat([WallpaperTheme.theme]) : presetThemes

    // Si se vuelve a crear el tema Wallpaper estando activo, sus colores cambian aunque el
    // nombre no: se aplican también a Alacritty y a Hyprland (onActiveThemeChanged no salta)
    Connections {
        target: WallpaperTheme
        function onThemeChanged() {
            if (activeTheme === WallpaperTheme.themeName) syncAll()
        }
    }

    // Los temas del repo (themes.js), en el orden del selector de la barra
    readonly property var presetThemes: Themes.presets

    // Color de acento de un tema: la casilla que dice "accent" ("base0D" -> casilla 13).
    // Aparte de roles() para quien solo necesita el acento (la muestra de cada tema en
    // ThemeSettings.qml, los bordes de Hyprland): roles() calcula además contrastes
    // WCAG, y el selector lo llamaría para todos los temas cada vez que se abre.
    function accentOf(theme) {
        return theme.base[parseInt(theme.accent.slice(4), 16)]
    }

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
            textSelected: accentOf(theme),  // Acento
            error:        b[8]      // Errores y avisos graves (base08, el rojo), como hace Stylix
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

    // Tema claro (fondo claro) u oscuro, según la luminancia de base00. Lo usan el
    // selector (ThemeSettings.qml) y los colores de Alacritty (alacrittyText())
    function isLight(theme) {
        return luminance(theme.base[0]) > 0.18
    }

    readonly property var scheme:  themeByName(activeTheme)        // El tema activo entero (nombre, acento y sus 16 colores)
    readonly property var current: roles(scheme)
    readonly property var base:    scheme.base                     // Los 16 colores del tema activo, por si algún widget necesita un rojo, un verde...

    readonly property color background:   current.background
    readonly property color textActive:   current.textActive
    readonly property color textSelected: current.textSelected
    readonly property color textDisabled: current.textDisabled
    readonly property color surface:      current.surface
    readonly property color surfaceHover: current.surfaceHover
    readonly property color border:       current.border
    readonly property color error:        current.error

    // Alacritty es un proceso aparte y no puede leer este QML directamente,
    // así que se le regenera su colors.toml (ver apps/alacritty/alacritty.toml,
    // que lo importa) cada vez que cambia el tema. Alacritty recarga solo
    // porque tiene live_config_reload activado por defecto.
    //
    // Los 16 colores se reparten como el estándar de Base16 para terminales: fondo
    // base00, texto base05, y los acentos base08–0E a rojo, amarillo, verde, cian,
    // azul y morado. Los "bright" repiten los normales (Base16 no tiene más colores
    // para diferenciarlos). Donde el reparto estándar se lee mal en algunos temas,
    // se elige el color que más contraste:
    //   - Negro: en un tema oscuro, base01 (casi como el fondo, lo normal); en uno
    //     claro, base02: un gris claro que se distingue del fondo y sobre el que el
    //     blanco (base05) se lee. El estándar pone base00 y el texto negro no se
    //     vería; con base05 el negro sería igual que el blanco, y el texto blanco
    //     sobre fondo negro (barras de estado, htop...) no se leería.
    //   - Negro brillante (comentarios, sugerencias de fish): base03 o base04, con
    //     el mismo criterio que el texto apagado de la barra (textDisabled de roles()).
    //   - Blanco brillante: base05, base06 o base07, el que más se distinga del fondo
    //     (en algunos temas base06 y base07 son colores de acento o casi el fondo).
    //   - Texto seleccionado: sobre base02, el que mejor se lea de base05, base00 y base07.
    function alacrittyText(theme) {
        const b = theme.base
        const bg = b[0], fg = b[5]
        // El de más contraste con "against"; con empate, el primero (como max() de Python)
        const best = (colors, against) => colors.reduce((a, c) => contrast(c, against) > contrast(a, against) ? c : a)

        const black         = isLight(theme) ? b[2] : b[1]
        const brightBlack   = roles(theme).textDisabled
        const brightWhite   = best([b[5], b[6], b[7]], bg)
        const selectionText = best([fg, bg, b[7]], b[2])

        const accents = 'red     = "' + b[8] + '"\n'
                      + 'green   = "' + b[11] + '"\n'
                      + 'yellow  = "' + b[10] + '"\n'
                      + 'blue    = "' + b[13] + '"\n'
                      + 'magenta = "' + b[14] + '"\n'
                      + 'cyan    = "' + b[12] + '"\n'

        return "# Autogenerado por quickshell/services/Theme.qml a partir del tema activo\n"
             + "# No editar a mano: se sobrescribe en cada cambio de tema.\n"
             + "\n"
             + "[colors.primary]\n"
             + 'background = "' + bg + '"\n'
             + 'foreground = "' + fg + '"\n'
             + "\n"
             + "[colors.cursor]\n"
             + 'text   = "' + bg + '"\n'
             + 'cursor = "' + fg + '"\n'
             + "\n"
             + "[colors.selection]\n"
             + 'text       = "' + selectionText + '"\n'
             + 'background = "' + b[2] + '"\n'
             + "\n"
             + "[colors.normal]\n"
             + 'black   = "' + black + '"\n'
             + accents
             + 'white   = "' + fg + '"\n'
             + "\n"
             + "[colors.bright]\n"
             + 'black   = "' + brightBlack + '"\n'
             + accents
             + 'white   = "' + brightWhite + '"\n'
    }

    // install.sh crea ~/.config/alacritty (ahí enlaza alacritty.toml), así que la carpeta ya existe
    FileView {
        id: alacrittyFile
        path: Quickshell.env("HOME") + "/.config/alacritty/colors.toml"
        atomicWrites: true
        blockLoading: true                                  // Para que text() devuelva ya el contenido actual al arrancar
    }

    function syncAlacritty() {
        const text = alacrittyText(themeByName(activeTheme))   // Directo del tema, no de las propiedades derivadas (lo mismo que en hyprConfigText())
        if (alacrittyFile.text() === text) return           // Si no ha cambiado nada no se toca (lo normal en cada arranque de Quickshell)
        alacrittyFile.setText(text)
    }

    // Lo mismo para los bordes de las ventanas y el color de fondo, que los pinta Hyprland: igual
    // que Geometry.qml con las medidas de las ventanas, se aplican en caliente y se guardan en
    // ~/.config/hypr/shellTheme.lua para el siguiente arranque, con components/HyprConfigFile.qml.
    function hyprColor(c, alpha) {
        return "0x" + alpha + c.toString().slice(1)     // "#rrggbb" -> 0xAARRGGBB, el formato de hyprland.lua
    }

    // Tablas "general = {...}, misc = {...}" que se pasan a hl.config(), en una línea (vale tanto para el archivo como para "hyprctl eval")
    // Colores como los pone Stylix (https://github.com/nix-community/stylix, módulo de Hyprland):
    // bordes de color liso y opaco, sin degradado ni transparencia. Activo: el acento (en Stylix
    // base0D, que es el acento de casi todos los temas de aquí). Inactivo: base03.
    // Fondo (background_color): base00. Es lo que pinta Hyprland donde no hay nada encima, y
    // solo se ve mientras Quickshell no está en marcha (al arrancar o al reiniciarlo), porque
    // el resto del tiempo lo tapa el fondo de pantalla de Background.qml.
    function hyprConfigText() {
        const theme = themeByName(activeTheme)          // Directo del tema, no de las propiedades derivadas: puede que aún no se hayan actualizado al saltar onActiveThemeChanged
        return "general = { col = { "
             + "active_border = " + hyprColor(accentOf(theme), "ff") + ", "
             + "inactive_border = " + hyprColor(theme.base[3], "ff")
             + " } }, "
             + "misc = { background_color = " + hyprColor(theme.base[0], "ff") + " }"
    }

    HyprConfigFile {
        id: hyprThemeFile
        name: "shellTheme"
        generator: "Theme.qml"
    }

    function syncHyprland() { hyprThemeFile.sync(hyprConfigText()) }

    function syncAll() {
        syncAlacritty()
        syncHyprland()
    }

    onActiveThemeChanged: syncAll()
}
