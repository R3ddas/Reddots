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
    property alias borderShadow: adapter.borderShadow
    property alias popupRounding: adapter.popupRounding
    property alias popupBorderWidth: adapter.popupBorderWidth

    // Registro de propiedades editables: GeometrySettings.qml construye su
    // panel iterando esta lista (concatenada con la de HyprGeometry.qml), así
    // que añadir aquí una entrada es lo único que hace falta para que
    // aparezca un nuevo control en el panel. "target" indica en qué singleton
    // vive de verdad la propiedad (aquí o en HyprGeometry).
    readonly property var editable: [
        { target: root, key: "sidebarWidth",    label: "Ancho barra lateral",  min: 16, max: 80, step: 1 },
        { target: root, key: "borderThickness", label: "Grosor del borde",     min: 0,  max: 20, step: 1 },
        { target: root, key: "borderRounding",  label: "Redondeo de esquinas", min: 0,  max: 40, step: 1 },
        { target: root, key: "borderShadow",    label: "Sombra del borde",     min: 0,  max: 40, step: 1 },
        { target: root, key: "popupRounding",   label: "Redondeo desplegables", min: 0, max: 40, step: 1 },
        { target: root, key: "popupBorderWidth", label: "Borde desplegables",   min: 0, max: 10, step: 1 }
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
            property int borderShadow: 5       // Cuántos px hacia adentro se difumina la sombra de Border (0 = sin sombra)
            property int popupRounding: 16     // Radio de las esquinas de los desplegables de la barra
            property int popupBorderWidth: 2   // Grosor del borde de color de los desplegables y del lanzador (0 = sin borde)
        }
    }
}
