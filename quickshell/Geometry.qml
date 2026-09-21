pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Medidas compartidas de la "carcasa" de la interfaz (barra lateral + borde),
// para que Border.qml y shell.qml no dupliquen los mismos números y puedan
// desincronizarse entre sí. Editable en caliente desde GeometrySettings.qml
// y persistida en disco (fuera del repo, en el directorio de estado de
// Quickshell) para que los ajustes sobrevivan a un reinicio.
//
// Solo cubre propiedades que vive Quickshell (bindings QML normales, efecto
// inmediato). Las que vive Hyprland (gaps, borde/redondeo de ventana) están
// en el singleton paralelo HyprGeometry.qml, que persiste igual pero aplica
// los cambios de otra forma porque no hay binding posible con el compositor.
Singleton {
    id: root

    property alias sidebarWidth: adapter.sidebarWidth
    property alias borderThickness: adapter.borderThickness
    property alias borderRounding: adapter.borderRounding

    // Registro de propiedades editables: GeometrySettings.qml construye su
    // panel iterando esta lista (concatenada con la de HyprGeometry.qml), así
    // que añadir aquí una entrada es lo único que hace falta para que
    // aparezca un nuevo control en el panel. "target" indica en qué singleton
    // vive de verdad la propiedad (aquí o en HyprGeometry).
    readonly property var editable: [
        { target: root, key: "sidebarWidth",    label: "Ancho barra lateral",  min: 16, max: 80, step: 1 },
        { target: root, key: "borderThickness", label: "Grosor del borde",     min: 0,  max: 20, step: 1 },
        { target: root, key: "borderRounding",  label: "Redondeo de esquinas", min: 0,  max: 40, step: 1 }
    ]

    FileView {
        path: Quickshell.statePath("geometry.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter
            property int sidebarWidth: 32      // Ancho de la barra lateral (PanelWindow.implicitWidth y Border.margins.left deben coincidir)
            property int borderThickness: 6    // Grosor del marco que dibuja Border
            property int borderRounding: 22    // Radio de las esquinas redondeadas de Border
        }
    }
}
