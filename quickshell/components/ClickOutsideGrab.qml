// Cierra "window" al hacer clic fuera de ella, con un HyprlandFocusGrab. Lo usan los
// desplegables de la barra (BarPopup.qml) y las ventanas sueltas (OverlayWindow.qml):
// basta con ponerlo dentro y darle la ventana.
import Quickshell.Hyprland          // Para el HyprlandFocusGrab
import QtQuick

Item {
    id: root

    required property var window        // La ventana (PopupWindow o PanelWindow) que se cierra

    Connections {
        target: root.window
        function onVisibleChanged() {
            if (root.window.visible) grabTimer.restart()
            else { grabTimer.stop(); grab.active = false }
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [root.window]
        active: false
        onCleared: root.window.visible = false
    }

    Timer {
        id: grabTimer
        interval: 5                     // Deja que la ventana termine de abrirse antes de activar el grab (si no, la cierra el mismo clic que la abrió)
        onTriggered: grab.active = true
    }
}
