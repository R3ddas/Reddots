pragma Singleton
import Quickshell
import QtQuick

Singleton {
    readonly property color background:   "#454138"     // Color de la barra lateral y el recuadro

    readonly property color textActive:   "#f5e2c5"     // Caracteres activos en la barra lateral
    readonly property color textSelected: "#5a4d3e"     // Caracteres seleccionados en la barra lateral
    readonly property color textDisabled: "#a8957c"     // Caracteres inactivos en la barra lateral

    readonly property color surface: "#1c1714"
    readonly property color surfaceHover: "#2b2320"
    readonly property color border: "#5a4d3e"
}
