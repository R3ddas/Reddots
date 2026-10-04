pragma Singleton
import Quickshell
import Quickshell.Io                // Para los IpcHandler
import QtQuick

// Órdenes que llegan de fuera con "qs ipc call <target> <función>": las mandan los atajos
// de hypr/keybinds.lua (Super, Super + V, teclas de volumen y brillo).
//
// Los IpcHandler están aquí, en un singleton, y no en cada ventana: las ventanas van
// dentro del Variants de la pantalla (shell.qml) y se destruyen y se crean de nuevo al
// cerrar la tapa o cambiar de monitor. Mientras la nueva y la vieja convivían, había dos
// handlers para el mismo target (el aviso "Handler was registered but will not be used"
// del log) y la orden podía llegar a la ventana que se estaba yendo. Aquí hay uno solo,
// que avisa con una señal; cada ventana la escucha con un Connections.
//
// No están todos: "qs ipc call updates refresh" (lo manda scripts/update-reddots.sh) vive
// en services/Updates.qml. Allí no hay ese problema, porque ya es un singleton.
Singleton {
    id: root

    signal launcherToggled()            // windows/Launcher.qml
    signal clipboardToggled()           // windows/Clipboard.qml
    signal osdRequested(string mode)    // windows/Osd.qml: "volume", "mic" o "brightness"

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.launcherToggled() }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.clipboardToggled() }
    }

    IpcHandler {
        target: "osd"
        function volume(): void { root.osdRequested("volume") }
        function mic(): void { root.osdRequested("mic") }
        function brightness(): void { root.osdRequested("brightness") }
    }
}
