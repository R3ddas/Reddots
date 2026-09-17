pragma Singleton
import Quickshell
import QtQuick

Singleton {
    // Elige el tema activo cambiando este índice:
    // 0: Original       (marrón cálido, el de siempre)
    // 1: Gruvbox Claro
    // 2: Gruvbox Oscuro
    // 3: Everforest Claro
    // 4: Everforest Oscuro
    readonly property int activeTheme: 0

    readonly property var themes: [
        // 0 - Original
        QtObject {
            readonly property color background:   "#454138"     // Color de la barra lateral y el recuadro
            readonly property color textActive:   "#f5e2c5"     // Caracteres activos en la barra lateral
            readonly property color textSelected: "#db911a"     // Caracteres seleccionados en la barra lateral
            readonly property color textDisabled: "#837564"     // Caracteres inactivos en la barra lateral
            readonly property color surface:      "#454138"     // Color de las ventanas flotantes
            readonly property color surfaceHover: "#a8957c"     // Color de los componentes sobre los que está el ratón en las ventanas flotantes
            readonly property color border:       "#5a4d3e"     // Color del borde de las ventanas flotantes
        },
        // 1 - Gruvbox Claro: crema cálido, a juego con el fondo del wallpaper
        QtObject {
            readonly property color background:   "#fbf1c7"
            readonly property color textActive:   "#3c3836"
            readonly property color textSelected: "#af3a03"
            readonly property color textDisabled: "#a89984"
            readonly property color surface:      "#ebdbb2"
            readonly property color surfaceHover: "#d5c4a1"
            readonly property color border:       "#bdae93"
        },
        // 2 - Gruvbox Oscuro: versión oscura del anterior, tinta y carbón
        QtObject {
            readonly property color background:   "#282828"
            readonly property color textActive:   "#ebdbb2"
            readonly property color textSelected: "#fe8019"
            readonly property color textDisabled: "#928374"
            readonly property color surface:      "#3c3836"
            readonly property color surfaceHover: "#504945"
            readonly property color border:       "#504945"
        },
        // 3 - Everforest Claro: crema suave y natural, acento rojizo como el sello del wallpaper
        QtObject {
            readonly property color background:   "#fdf6e3"
            readonly property color textActive:   "#5c6a72"
            readonly property color textSelected: "#f57d26"
            readonly property color textDisabled: "#a6b0a0"
            readonly property color surface:      "#f4f0d9"
            readonly property color surfaceHover: "#e5ddc8"
            readonly property color border:       "#e0dcc7"
        },
        // 4 - Everforest Oscuro: versión oscura del anterior, grises y verdes apagados
        QtObject {
            readonly property color background:   "#2d353b"
            readonly property color textActive:   "#d3c6aa"
            readonly property color textSelected: "#e69875"
            readonly property color textDisabled: "#859289"
            readonly property color surface:      "#343f44"
            readonly property color surfaceHover: "#475258"
            readonly property color border:       "#475258"
        }
    ]

    readonly property color background:   themes[activeTheme].background
    readonly property color textActive:   themes[activeTheme].textActive
    readonly property color textSelected: themes[activeTheme].textSelected
    readonly property color textDisabled: themes[activeTheme].textDisabled
    readonly property color surface:      themes[activeTheme].surface
    readonly property color surfaceHover: themes[activeTheme].surfaceHover
    readonly property color border:       themes[activeTheme].border
}
