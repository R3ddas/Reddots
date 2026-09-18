pragma Singleton
import Quickshell
import QtQuick

// Medidas compartidas de la "carcasa" de la interfaz (barra lateral + borde),
// para que Border.qml y shell.qml no dupliquen los mismos números y puedan
// desincronizarse entre sí.
Singleton {
    readonly property int sidebarWidth: 32      // Ancho de la barra lateral (PanelWindow.implicitWidth y Border.margins.left deben coincidir)
    readonly property int borderThickness: 6    // Grosor del marco que dibuja Border
    readonly property int borderRounding: 22    // Radio de las esquinas redondeadas de Border
}
