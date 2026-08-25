// Recursos: https://tonybtw.com/tutorial/quickshell/

import Quickshell
import Quickshell.Hyprland // Para acceder a los WorkSpaces
import QtQuick
import QtQuick.Layouts // Para usar RowLayout o ColumnLayout

ShellRoot {
    PanelWindow {
        //anchors { top: true; left: true; right: true }
        anchors { top: true; bottom: true; left: true }
        //implicitHeight: 32
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
            onTriggered: reloj.hora = new Date().toLocaleString(Qt.locale(), "ddd d MMM  hh:mm")
        }

        // Gestión de WorkSpaces--------------------------------------------------
        //RowLayout{
        ColumnLayout{
            anchors.fill: parent
            anchors.margins: 6
            Repeater{ // Repite algo N veces
                model:9
                Text{
                    property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                    property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
                    text: index + 1
                    //The color logic is straightforward: cyan if it’s the active workspace, blue if it exists but isn’t active, and muted gray if there’s no windows on that workspace.
                    color: isActive ? "#0db9d7" : (ws ? "#7aa2f7" : "#444b6a")
                    font { pixelSize: 14; bold: true }
                    Layout.alignment: Qt.AlignHCenter // Centro verticalemente los números
    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Hyprland.dispatch("workspace " + (index + 1))
                    }
                }
            }
            //Item { Layout.fillWidth: true } // Añade espacios entre los WorkSpaces
            Item { Layout.fillheight: true } // Añade espacios entre los WorkSpaces
        }
    }
}
