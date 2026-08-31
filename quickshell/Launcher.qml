// Launcher.qml
// Widget que aparece al pulsar Super solo (sin combinar con otra tecla), anclado abajo-derecha
// De momento solo dibuja el marco; a futuro mostrará las aplicaciones instaladas

import Quickshell
import Quickshell.Io      // Para el IpcHandler
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    visible: false

    anchors { bottom: true; right: true }

    implicitWidth: 600
    implicitHeight: 70

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "reddots:launcher"

    Rectangle {
        anchors.fill: parent
        topLeftRadius: 24        // Solo la esquina superior izquierda es redondeada, el resto llega al borde de la pantalla
        color: Theme.surface
        border.color: Theme.border
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.visible = !root.visible
        }
    }
}
