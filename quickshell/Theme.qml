pragma Singleton
import Quickshell
import QtQuick

Singleton {
    // Elige el tema activo escribiendo su nombre aquí (debe coincidir con
    // el "name" de una de las entradas de themes, más abajo):
    //   "Original", "Gruvbox Claro", "Gruvbox Oscuro",
    //   "Everforest Claro", "Everforest Oscuro",
    //   "Rosé Pine Claro", "Rosé Pine Oscuro",
    //   "Catppuccin Claro", "Catppuccin Oscuro",
    //   "Nord Oscuro", "Dracula Oscuro",
    //   "Solarized Claro", "Solarized Oscuro",
    //   "Tokyo Night Oscuro", "One Dark Oscuro",
    //   "Everblush Oscuro", "Old World Oscuro",
    //   "Shado Theme Oscuro", "Dark Green Oscuro",
    //   "Caelestia Claro", "Caelestia Oscuro"
    readonly property string activeTheme: "Rosé Pine Claro"

    function themeByName(themeName) {
        for (var i = 0; i < themes.length; i++) {
            if (themes[i].name === themeName)
                return themes[i]
        }
        return themes[0]
    }

    readonly property list<QtObject> themes: [
        QtObject {
            readonly property string name:        "Original"
            readonly property color background:   "#454138"     // Color de la barra lateral y el recuadro
            readonly property color textActive:   "#f5e2c5"     // Caracteres activos en la barra lateral
            readonly property color textSelected: "#db911a"     // Caracteres seleccionados en la barra lateral
            readonly property color textDisabled: "#837564"     // Caracteres inactivos en la barra lateral
            readonly property color surface:      "#454138"     // Color de las ventanas flotantes
            readonly property color surfaceHover: "#a8957c"     // Color de los componentes sobre los que está el ratón en las ventanas flotantes
            readonly property color border:       "#5a4d3e"     // Color del borde de las ventanas flotantes
        },
        // Gruvbox Claro: crema cálido, a juego con el fondo del wallpaper
        QtObject {
            readonly property string name:        "Gruvbox Claro"
            readonly property color background:   "#fbf1c7"
            readonly property color textActive:   "#3c3836"
            readonly property color textSelected: "#af3a03"
            readonly property color textDisabled: "#a89984"
            readonly property color surface:      "#ebdbb2"
            readonly property color surfaceHover: "#d5c4a1"
            readonly property color border:       "#bdae93"
        },
        // Gruvbox Oscuro: versión oscura del anterior, tinta y carbón
        QtObject {
            readonly property string name:        "Gruvbox Oscuro"
            readonly property color background:   "#282828"
            readonly property color textActive:   "#ebdbb2"
            readonly property color textSelected: "#fe8019"
            readonly property color textDisabled: "#928374"
            readonly property color surface:      "#3c3836"
            readonly property color surfaceHover: "#504945"
            readonly property color border:       "#504945"
        },
        // Everforest Claro: crema suave y natural, acento rojizo como el sello del wallpaper
        QtObject {
            readonly property string name:        "Everforest Claro"
            readonly property color background:   "#fdf6e3"
            readonly property color textActive:   "#5c6a72"
            readonly property color textSelected: "#f57d26"
            readonly property color textDisabled: "#a6b0a0"
            readonly property color surface:      "#f4f0d9"
            readonly property color surfaceHover: "#e5ddc8"
            readonly property color border:       "#e0dcc7"
        },
        // Everforest Oscuro: versión oscura del anterior, grises y verdes apagados
        QtObject {
            readonly property string name:        "Everforest Oscuro"
            readonly property color background:   "#2d353b"
            readonly property color textActive:   "#d3c6aa"
            readonly property color textSelected: "#e69875"
            readonly property color textDisabled: "#859289"
            readonly property color surface:      "#343f44"
            readonly property color surfaceHover: "#475258"
            readonly property color border:       "#475258"
        },
        // Rosé Pine Claro (Dawn): crema rosado, acento vino a juego con el sello rojo
        QtObject {
            readonly property string name:        "Rosé Pine Claro"
            readonly property color background:   "#faf4ed"
            readonly property color textActive:   "#575279"
            readonly property color textSelected: "#b4637a"
            readonly property color textDisabled: "#9893a5"
            readonly property color surface:      "#fffaf3"
            readonly property color surfaceHover: "#dfdad9"
            readonly property color border:       "#cecacd"
        },
        // Rosé Pine Oscuro (Main): versión oscura del anterior, malva y ciruela
        QtObject {
            readonly property string name:        "Rosé Pine Oscuro"
            readonly property color background:   "#191724"
            readonly property color textActive:   "#e0def4"
            readonly property color textSelected: "#eb6f92"
            readonly property color textDisabled: "#6e6a86"
            readonly property color surface:      "#1f1d2e"
            readonly property color surfaceHover: "#403d52"
            readonly property color border:       "#524f67"
        },
        // Catppuccin Claro (Latte): muy popular, crema frío con acento rojo
        QtObject {
            readonly property string name:        "Catppuccin Claro"
            readonly property color background:   "#eff1f5"
            readonly property color textActive:   "#4c4f69"
            readonly property color textSelected: "#d20f39"
            readonly property color textDisabled: "#9ca0b0"
            readonly property color surface:      "#e6e9ef"
            readonly property color surfaceHover: "#bcc0cc"
            readonly property color border:       "#ccd0da"
        },
        // Catppuccin Oscuro (Mocha): versión oscura del anterior, muy usada en dotfiles
        QtObject {
            readonly property string name:        "Catppuccin Oscuro"
            readonly property color background:   "#1e1e2e"
            readonly property color textActive:   "#cdd6f4"
            readonly property color textSelected: "#f38ba8"
            readonly property color textDisabled: "#6c7086"
            readonly property color surface:      "#181825"
            readonly property color surfaceHover: "#45475a"
            readonly property color border:       "#313244"
        },
        // Nord Oscuro
        QtObject {
            readonly property string name:        "Nord Oscuro"
            readonly property color background:   "#2e3440"
            readonly property color textActive:   "#eceff4"
            readonly property color textSelected: "#88c0d0"
            readonly property color textDisabled: "#4c566a"
            readonly property color surface:      "#3b4252"
            readonly property color surfaceHover: "#434c5e"
            readonly property color border:       "#4c566a"
        },
        // Dracula Oscuro
        QtObject {
            readonly property string name:        "Dracula Oscuro"
            readonly property color background:   "#282a36"
            readonly property color textActive:   "#f8f8f2"
            readonly property color textSelected: "#bd93f9"
            readonly property color textDisabled: "#6272a4"
            readonly property color surface:      "#343746"
            readonly property color surfaceHover: "#4d4f66"
            readonly property color border:       "#6272a4"
        },
        // Solarized Claro
        QtObject {
            readonly property string name:        "Solarized Claro"
            readonly property color background:   "#fdf6e3"
            readonly property color textActive:   "#586e75"
            readonly property color textSelected: "#268bd2"
            readonly property color textDisabled: "#93a1a1"
            readonly property color surface:      "#eee8d5"
            readonly property color surfaceHover: "#e4ddc8"
            readonly property color border:       "#93a1a1"
        },
        // Solarized Oscuro
        QtObject {
            readonly property string name:        "Solarized Oscuro"
            readonly property color background:   "#002b36"
            readonly property color textActive:   "#93a1a1"
            readonly property color textSelected: "#268bd2"
            readonly property color textDisabled: "#586e75"
            readonly property color surface:      "#073642"
            readonly property color surfaceHover: "#0d4250"
            readonly property color border:       "#586e75"
        },
        // Tokyo Night Oscuro
        QtObject {
            readonly property string name:        "Tokyo Night Oscuro"
            readonly property color background:   "#1a1b26"
            readonly property color textActive:   "#c0caf5"
            readonly property color textSelected: "#7aa2f7"
            readonly property color textDisabled: "#565f89"
            readonly property color surface:      "#24283b"
            readonly property color surfaceHover: "#2a2f41"
            readonly property color border:       "#414868"
        },
        // One Dark Oscuro
        QtObject {
            readonly property string name:        "One Dark Oscuro"
            readonly property color background:   "#282c34"
            readonly property color textActive:   "#abb2bf"
            readonly property color textSelected: "#61afef"
            readonly property color textDisabled: "#5c6370"
            readonly property color surface:      "#2c313a"
            readonly property color surfaceHover: "#3e4451"
            readonly property color border:       "#3b4048"
        },
        // Everblush Oscuro
        QtObject {
            readonly property string name:        "Everblush Oscuro"
            readonly property color background:   "#141b1e"
            readonly property color textActive:   "#e8e8e8"
            readonly property color textSelected: "#8ccfb0"
            readonly property color textDisabled: "#8a8f94"
            readonly property color surface:      "#232a2d"
            readonly property color surfaceHover: "#3a4145"
            readonly property color border:       "#3a4145"
        },
        // Old World Oscuro
        QtObject {
            readonly property string name:        "Old World Oscuro"
            readonly property color background:   "#121317"
            readonly property color textActive:   "#e3e2e7"
            readonly property color textSelected: "#aac7ff"
            readonly property color textDisabled: "#8e909a"
            readonly property color surface:      "#1e2023"
            readonly property color surfaceHover: "#292a2e"
            readonly property color border:       "#43474f"
        },
        // Shado Theme Oscuro
        QtObject {
            readonly property string name:        "Shado Theme Oscuro"
            readonly property color background:   "#131317"
            readonly property color textActive:   "#e5e1e7"
            readonly property color textSelected: "#bfc1ff"
            readonly property color textDisabled: "#918f9a"
            readonly property color surface:      "#1f1f23"
            readonly property color surfaceHover: "#2a292e"
            readonly property color border:       "#46464f"
        },
        // Dark Green Oscuro
        QtObject {
            readonly property string name:        "Dark Green Oscuro"
            readonly property color background:   "#23262d"
            readonly property color textActive:   "#f5f5f6"
            readonly property color textSelected: "#24bd5c"
            readonly property color textDisabled: "#979797"
            readonly property color surface:      "#23262c"
            readonly property color surfaceHover: "#1b1d22"
            readonly property color border:       "#1e1e25"
        },
        // Caelestia Claro
        QtObject {
            readonly property string name:        "Caelestia Claro"
            readonly property color background:   "#f6faf9"
            readonly property color textActive:   "#2a3433"
            readonly property color textSelected: "#1c6a66"
            readonly property color textDisabled: "#727d7c"
            readonly property color surface:      "#e7f0ee"
            readonly property color surfaceHover: "#e1eae8"
            readonly property color border:       "#a9b4b3"
        },
        // Caelestia Oscuro
        QtObject {
            readonly property string name:        "Caelestia Oscuro"
            readonly property color background:   "#0a0f0f"
            readonly property color textActive:   "#dce8e6"
            readonly property color textSelected: "#9bd0cc"
            readonly property color textDisabled: "#6d7876"
            readonly property color surface:      "#131b1a"
            readonly property color surfaceHover: "#192120"
            readonly property color border:       "#3f4a49"
        }
    ]

    readonly property QtObject current:   themeByName(activeTheme)

    readonly property color background:   current.background
    readonly property color textActive:   current.textActive
    readonly property color textSelected: current.textSelected
    readonly property color textDisabled: current.textDisabled
    readonly property color surface:      current.surface
    readonly property color surfaceHover: current.surfaceHover
    readonly property color border:       current.border
}
