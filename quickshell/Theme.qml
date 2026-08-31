pragma Singleton
import Quickshell
import QtQuick

Singleton {
    readonly property color background:   "#454138"     // Color de la barra lateral y el recuadro

    readonly property color textActive:   "#f5e2c5"     // Caracteres activos en la barra lateral
    readonly property color textSelected: "#db911a"     // Caracteres seleccionados en la barra lateral
    readonly property color textDisabled: "#837564"     // Caracteres inactivos en la barra lateral

    readonly property color surface:      "#454138"     // Color de las ventanas flotantes
    readonly property color surfaceHover: "#a8957c"     // Color de los componentes sobre los que está el ratón en las ventanas flotantes
    readonly property color border:       "#5a4d3e"     // Color del borde de las ventanas flotantes
}
