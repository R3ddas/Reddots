// Recursos: https://tonybtw.com/tutorial/quickshell/

import Quickshell
import Quickshell.Hyprland // Para acceder a los WorkSpaces
import QtQuick
import QtQuick.Layouts // Para usar RowLayout o ColumnLayout

ShellRoot {
    PanelWindow {
        anchors { top: true; bottom: true; left: true }
        implicitWidth: 32
        color: "#1e1e2e"
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6

            Workspaces{}        // Cambiador de Workspaces
            Clock{}             // Reloj
            Item { Layout.fillHeight: true } // Añade espacios entre los WorkSpaces
            Battery{}           // Icono de batería
        }

    }
}
