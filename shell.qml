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
        Text {
            anchors.centerIn: parent
            color: "#cdd6f4"
            font.pointSize: 11
            text: reloj.hora
        }

        // Reloj ----------------------------------------------------------------------------------------------
        QtObject {
            id: reloj
            property string hora: ""
        }
        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: reloj.hora = new Date().toLocaleString(Qt.locale(), "hh:\n:mm")
        }

        Workspaces{}

    }
}
