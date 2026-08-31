// Recursos: https://tonybtw.com/tutorial/quickshell/

import Quickshell
import Quickshell.Hyprland // Para acceder a los WorkSpaces
import QtQuick
import QtQuick.Layouts // Para usar RowLayout o ColumnLayout

ShellRoot {
    Border {
        thickness: 6
        rounding: 22
        frameColor: "#1e1e2e"
    }
    PanelWindow {
        anchors { top: true; bottom: true; left: true }
        implicitWidth: 32
        color: "#1e1e2e"
        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            anchors.leftMargin: 9       // Le sumo la mitad del borde que añade "Border"
            anchors.rightMargin: 3      // Le resto la mitad del borde que añade "Border"

            Workspaces{Layout.alignment: Qt.AlignHCenter}       // Cambiador de Workspaces
            Item { Layout.fillHeight: true }                    // Empuja el reloj hacia el centro
            Clock{Layout.alignment: Qt.AlignHCenter}            // Reloj (centrado verticalmente)
            Item { Layout.fillHeight: true }                    // Empuja el grupo inferior hacia abajo
            ColumnLayout{
                spacing: 5
                Network{Layout.alignment: Qt.AlignHCenter}      // Wifi
                Bluetooths{Layout.alignment: Qt.AlignHCenter}   // Bluetooth
                Battery{Layout.alignment: Qt.AlignHCenter}      // Icono de batería
            }
        }

    }
}
