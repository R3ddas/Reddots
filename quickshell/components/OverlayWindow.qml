// OverlayWindow.qml
// Ventana flotante por encima de todo que se cierra al hacer clic fuera, como los
// desplegables de la barra (BarPopup.qml) pero suelta en la pantalla. La usan el
// Launcher, el historial del portapapeles (Clipboard.qml) y la chuleta de atajos
// (Keybinds.qml). Empieza oculta: se abre y se cierra con "visible".
//
// Quien la usa pone el contenido, el tamaño, el namespace (WlrLayershell.namespace)
// y, si quiere, anchors (sin anchors el compositor la centra en la pantalla). Si
// necesita hacer algo al abrirse o cerrarse, puede poner su propio onVisibleChanged
// (se ejecutan los dos: el de aquí y el suyo).
import Quickshell
import Quickshell.Hyprland          // Para el HyprlandFocusGrab
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    visible: false

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // OnDemand y no Exclusive: con Exclusive Hyprland no deja salir el clic y el
    // HyprlandFocusGrab nunca se entera de que se ha pulsado fuera (no se cerraba).
    // El teclado le llega igual al abrirse, porque se lo da el propio grab.
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible) grabTimer.restart()
        else { grabTimer.stop(); grab.active = false }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [root]
        active: false
        onCleared: root.visible = false             // Se cierra al hacer clic fuera
    }

    Timer {
        id: grabTimer
        interval: 5                                 // Deja que la ventana termine de abrirse antes de activar el grab (si no, lo cierra el mismo clic que la abrió)
        onTriggered: grab.active = true
    }
}
