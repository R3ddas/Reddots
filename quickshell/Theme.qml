pragma Singleton
import Quickshell
import QtQuick

// Fuentes de las paletas:
//   Gruvbox              https://github.com/morhetz/gruvbox
//   Everforest            https://github.com/sainnhe/everforest
//   Rosé Pine              https://rosepinetheme.com/palette
//   Catppuccin            https://github.com/catppuccin/catppuccin
//   Nord                   https://www.nordtheme.com/docs/colors-and-palettes
//   Dracula                https://draculatheme.com/contribute
//   Solarized             https://ethanschoonover.com/solarized/
//   Tokyo Night           https://github.com/tokyo-night/tokyo-night-vscode-theme
//   One Dark               https://github.com/joshdick/onedark.vim
//   Everblush, Old World, Shado Theme, Dark Green y Caelestia (por defecto)
//                          https://github.com/caelestia-dots/cli/tree/main/src/caelestia/data/schemes
//   Monokai                paleta clásica de Sublime Text / monokai.pro
//   Kanagawa               https://github.com/rebelot/kanagawa.nvim
//   Ayu (Claro/Mirage/Oscuro) https://github.com/dempfi/ayu
//   Nightfox (Dayfox/Nightfox) https://github.com/EdenEast/nightfox.nvim
//   Oxocarbon              https://github.com/nyoom-engineering/oxocarbon.nvim (paleta IBM Carbon)
//   GitHub                 https://github.com/primer/github-vscode-theme
//   Zenburn                https://github.com/bbatsov/zenburn-emacs
//   Sonokai                https://github.com/sainnhe/sonokai
//   Horizon                https://github.com/jolaleye/horizon-theme-vscode
//
// Nota sobre Extra1/Extra2/Extra3: son tres colores de acento adicionales por si
// hacen falta más de los 7 básicos. Cuando la paleta de origen no tenía tres
// acentos "de sobra" (Original, Old World, Shado Theme, Dark Green y Caelestia),
// alguno de los tres se ha elegido a mano a juego con el resto, no viene de
// ninguna fuente online.
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
    //   "Caelestia Claro", "Caelestia Oscuro",
    //   "Monokai Oscuro", "Kanagawa Oscuro",
    //   "Ayu Claro", "Ayu Mirage", "Ayu Oscuro",
    //   "Nightfox Claro", "Nightfox Oscuro",
    //   "Oxocarbon Claro", "Oxocarbon Oscuro",
    //   "GitHub Claro", "GitHub Oscuro",
    //   "Zenburn Oscuro", "Sonokai Oscuro", "Horizon Oscuro"
    readonly property string activeTheme: "Gruvbox Claro"

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
            readonly property color extra1:       "#c1502e"     // Rojo teja (a mano)
            readonly property color extra2:       "#7c8b53"     // Verde oliva (a mano)
            readonly property color extra3:       "#6f8fa3"     // Azul apagado (a mano)
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
            readonly property color extra1:       "#b57614"     // Amarillo
            readonly property color extra2:       "#79740e"     // Verde
            readonly property color extra3:       "#076678"     // Azul
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
            readonly property color extra1:       "#fabd2f"     // Amarillo
            readonly property color extra2:       "#b8bb26"     // Verde
            readonly property color extra3:       "#83a598"     // Azul
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
            readonly property color extra1:       "#dfa000"     // Amarillo
            readonly property color extra2:       "#8da101"     // Verde
            readonly property color extra3:       "#3a94c5"     // Azul
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
            readonly property color extra1:       "#dbbc7f"     // Amarillo
            readonly property color extra2:       "#a7c080"     // Verde
            readonly property color extra3:       "#7fbbb3"     // Azul
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
            readonly property color extra1:       "#ea9d34"     // Gold
            readonly property color extra2:       "#286983"     // Pine
            readonly property color extra3:       "#907aa9"     // Iris
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
            readonly property color extra1:       "#f6c177"     // Gold
            readonly property color extra2:       "#9ccfd8"     // Foam
            readonly property color extra3:       "#c4a7e7"     // Iris
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
            readonly property color extra1:       "#df8e1d"     // Amarillo
            readonly property color extra2:       "#40a02b"     // Verde
            readonly property color extra3:       "#1e66f5"     // Azul
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
            readonly property color extra1:       "#f9e2af"     // Amarillo
            readonly property color extra2:       "#a6e3a1"     // Verde
            readonly property color extra3:       "#89b4fa"     // Azul
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
            readonly property color extra1:       "#ebcb8b"     // Amarillo
            readonly property color extra2:       "#a3be8c"     // Verde
            readonly property color extra3:       "#b48ead"     // Morado
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
            readonly property color extra1:       "#50fa7b"     // Verde
            readonly property color extra2:       "#8be9fd"     // Cian
            readonly property color extra3:       "#ff79c6"     // Rosa
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
            readonly property color extra1:       "#b58900"     // Amarillo
            readonly property color extra2:       "#859900"     // Verde
            readonly property color extra3:       "#2aa198"     // Cian
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
            readonly property color extra1:       "#b58900"     // Amarillo
            readonly property color extra2:       "#859900"     // Verde
            readonly property color extra3:       "#2aa198"     // Cian
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
            readonly property color extra1:       "#e0af68"     // Amarillo
            readonly property color extra2:       "#9ece6a"     // Verde
            readonly property color extra3:       "#bb9af7"     // Morado
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
            readonly property color extra1:       "#e5c07b"     // Amarillo
            readonly property color extra2:       "#98c379"     // Verde
            readonly property color extra3:       "#c678dd"     // Morado
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
            readonly property color extra1:       "#e5c76b"     // Amarillo
            readonly property color extra2:       "#67b0e8"     // Azul
            readonly property color extra3:       "#b279db"     // Morado
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
            readonly property color extra1:       "#bcc7df"     // Secundario de la paleta
            readonly property color extra2:       "#ffb4ab"     // Rojo de error de la paleta
            readonly property color extra3:       "#d6c2a1"     // Tostado (a mano)
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
            readonly property color extra1:       "#c5c4e0"     // Secundario de la paleta
            readonly property color extra2:       "#ffb4ab"     // Rojo de error de la paleta
            readonly property color extra3:       "#a0e0c8"     // Verde agua (a mano)
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
            readonly property color extra1:       "#c66e73"     // Rojo de error de la paleta
            readonly property color extra2:       "#4fd67d"     // Verde claro (a mano)
            readonly property color extra3:       "#d9a441"     // Ámbar (a mano)
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
            readonly property color extra1:       "#4a6462"     // Secundario de la paleta
            readonly property color extra2:       "#a83836"     // Rojo de error de la paleta
            readonly property color extra3:       "#6a8caa"     // Azul (a mano)
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
            readonly property color extra1:       "#b0ccc9"     // Secundario de la paleta
            readonly property color extra2:       "#fa746f"     // Rojo de error de la paleta
            readonly property color extra3:       "#d9c98a"     // Arena cálida (a mano)
        },
        // Monokai Oscuro
        QtObject {
            readonly property string name:        "Monokai Oscuro"
            readonly property color background:   "#272822"
            readonly property color textActive:   "#f8f8f2"
            readonly property color textSelected: "#a6e22e"
            readonly property color textDisabled: "#75715e"
            readonly property color surface:      "#383830"
            readonly property color surfaceHover: "#49483e"
            readonly property color border:       "#49483e"
            readonly property color extra1:       "#f92672"     // Rosa/rojo
            readonly property color extra2:       "#66d9ef"     // Cian
            readonly property color extra3:       "#e6db74"     // Amarillo
        },
        // Kanagawa Oscuro (Wave)
        QtObject {
            readonly property string name:        "Kanagawa Oscuro"
            readonly property color background:   "#1f1f28"
            readonly property color textActive:   "#dcd7ba"
            readonly property color textSelected: "#7fb4ca"
            readonly property color textDisabled: "#727169"
            readonly property color surface:      "#16161d"
            readonly property color surfaceHover: "#2a2a37"
            readonly property color border:       "#252535"
            readonly property color extra1:       "#c34043"     // Rojo otoñal
            readonly property color extra2:       "#76946a"     // Verde otoñal
            readonly property color extra3:       "#dca561"     // Amarillo otoñal
        },
        // Ayu Claro
        QtObject {
            readonly property string name:        "Ayu Claro"
            readonly property color background:   "#fcfcfc"
            readonly property color textActive:   "#5c6166"
            readonly property color textSelected: "#fa8d3e"
            readonly property color textDisabled: "#787b80"
            readonly property color surface:      "#f3f4f5"
            readonly property color surfaceHover: "#e7e8e9"
            readonly property color border:       "#e0e1e2"
            readonly property color extra1:       "#86b300"     // Verde
            readonly property color extra2:       "#55b4d4"     // Azul
            readonly property color extra3:       "#a37acc"     // Morado
        },
        // Ayu Mirage
        QtObject {
            readonly property string name:        "Ayu Mirage"
            readonly property color background:   "#242936"
            readonly property color textActive:   "#cccac2"
            readonly property color textSelected: "#ffcc66"
            readonly property color textDisabled: "#b8cfe6"
            readonly property color surface:      "#1f2430"
            readonly property color surfaceHover: "#2d3343"
            readonly property color border:       "#333944"
            readonly property color extra1:       "#d5ff80"     // Verde
            readonly property color extra2:       "#ffad66"     // Naranja
            readonly property color extra3:       "#ff6666"     // Rojo
        },
        // Ayu Oscuro
        QtObject {
            readonly property string name:        "Ayu Oscuro"
            readonly property color background:   "#10141c"
            readonly property color textActive:   "#bfbdb6"
            readonly property color textSelected: "#e6b450"
            readonly property color textDisabled: "#acb6bf"
            readonly property color surface:      "#0d1017"
            readonly property color surfaceHover: "#151a21"
            readonly property color border:       "#1b222c"
            readonly property color extra1:       "#aad94c"     // Verde
            readonly property color extra2:       "#d2a6ff"     // Morado
            readonly property color extra3:       "#f07178"     // Rojo
        },
        // Nightfox Claro (Dayfox)
        QtObject {
            readonly property string name:        "Nightfox Claro"
            readonly property color background:   "#f6f2ee"
            readonly property color textActive:   "#3d2b5a"
            readonly property color textSelected: "#a5222f"
            readonly property color textDisabled: "#837a72"
            readonly property color surface:      "#e4dcd4"
            readonly property color surfaceHover: "#dbd1dd"
            readonly property color border:       "#d3c7bb"
            readonly property color extra1:       "#396847"     // Verde
            readonly property color extra2:       "#2848a9"     // Azul
            readonly property color extra3:       "#ac5402"     // Amarillo/naranja
        },
        // Nightfox Oscuro
        QtObject {
            readonly property string name:        "Nightfox Oscuro"
            readonly property color background:   "#192330"
            readonly property color textActive:   "#cdcecf"
            readonly property color textSelected: "#719cd6"
            readonly property color textDisabled: "#738091"
            readonly property color surface:      "#212e3f"
            readonly property color surfaceHover: "#29394f"
            readonly property color border:       "#39506d"
            readonly property color extra1:       "#c94f6d"     // Rojo
            readonly property color extra2:       "#81b29a"     // Verde
            readonly property color extra3:       "#dbc074"     // Amarillo
        },
        // Oxocarbon Claro (paleta IBM Carbon)
        QtObject {
            readonly property string name:        "Oxocarbon Claro"
            readonly property color background:   "#ffffff"
            readonly property color textActive:   "#161616"
            readonly property color textSelected: "#0f62fe"
            readonly property color textDisabled: "#90a4ae"
            readonly property color surface:      "#f2f4f8"
            readonly property color surfaceHover: "#e0e5eb"
            readonly property color border:       "#d8dee4"
            readonly property color extra1:       "#ff7eb6"     // Rosa
            readonly property color extra2:       "#42be65"     // Verde
            readonly property color extra3:       "#673ab7"     // Morado
        },
        // Oxocarbon Oscuro (paleta IBM Carbon)
        QtObject {
            readonly property string name:        "Oxocarbon Oscuro"
            readonly property color background:   "#161616"
            readonly property color textActive:   "#ffffff"
            readonly property color textSelected: "#78a9ff"
            readonly property color textDisabled: "#b0b0b0"
            readonly property color surface:      "#201f1f"
            readonly property color surfaceHover: "#2a2a2a"
            readonly property color border:       "#3a3a3a"
            readonly property color extra1:       "#ee5396"     // Rosa
            readonly property color extra2:       "#42be65"     // Verde
            readonly property color extra3:       "#be95ff"     // Morado
        },
        // GitHub Claro
        QtObject {
            readonly property string name:        "GitHub Claro"
            readonly property color background:   "#ffffff"
            readonly property color textActive:   "#1f2328"
            readonly property color textSelected: "#0969da"
            readonly property color textDisabled: "#656d76"
            readonly property color surface:      "#f6f8fa"
            readonly property color surfaceHover: "#eaeef2"
            readonly property color border:       "#d0d7de"
            readonly property color extra1:       "#1a7f37"     // Verde
            readonly property color extra2:       "#cf222e"     // Rojo
            readonly property color extra3:       "#8250df"     // Morado
        },
        // GitHub Oscuro
        QtObject {
            readonly property string name:        "GitHub Oscuro"
            readonly property color background:   "#0d1117"
            readonly property color textActive:   "#e6edf3"
            readonly property color textSelected: "#2f81f7"
            readonly property color textDisabled: "#7d8590"
            readonly property color surface:      "#161b22"
            readonly property color surfaceHover: "#21262d"
            readonly property color border:       "#30363d"
            readonly property color extra1:       "#3fb950"     // Verde
            readonly property color extra2:       "#f85149"     // Rojo
            readonly property color extra3:       "#a371f7"     // Morado
        },
        // Zenburn Oscuro
        QtObject {
            readonly property string name:        "Zenburn Oscuro"
            readonly property color background:   "#3f3f3f"
            readonly property color textActive:   "#dcdccc"
            readonly property color textSelected: "#8cd0d3"
            readonly property color textDisabled: "#656555"
            readonly property color surface:      "#4f4f4f"
            readonly property color surfaceHover: "#383838"
            readonly property color border:       "#2b2b2b"
            readonly property color extra1:       "#cc9393"     // Rojo
            readonly property color extra2:       "#7f9f7f"     // Verde
            readonly property color extra3:       "#f0dfaf"     // Amarillo
        },
        // Sonokai Oscuro
        QtObject {
            readonly property string name:        "Sonokai Oscuro"
            readonly property color background:   "#2c2e34"
            readonly property color textActive:   "#e2e2e3"
            readonly property color textSelected: "#fc5d7c"
            readonly property color textDisabled: "#7f8490"
            readonly property color surface:      "#33353f"
            readonly property color surfaceHover: "#363944"
            readonly property color border:       "#3b3e48"
            readonly property color extra1:       "#9ed072"     // Verde
            readonly property color extra2:       "#76cce0"     // Azul
            readonly property color extra3:       "#e7c664"     // Amarillo
        },
        // Horizon Oscuro
        QtObject {
            readonly property string name:        "Horizon Oscuro"
            readonly property color background:   "#1c1e26"
            readonly property color textActive:   "#d5d8da"
            readonly property color textSelected: "#e95678"
            readonly property color textDisabled: "#6c6f93"
            readonly property color surface:      "#232530"
            readonly property color surfaceHover: "#2b2d3a"
            readonly property color border:       "#333548"
            readonly property color extra1:       "#fab795"     // Melocotón
            readonly property color extra2:       "#26bbd9"     // Azul
            readonly property color extra3:       "#27d797"     // Verde
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
    readonly property color extra1:       current.extra1
    readonly property color extra2:       current.extra2
    readonly property color extra3:       current.extra3
}
