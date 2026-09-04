// Recursos: https://tonybtw.com/tutorial/quickshell/

import Quickshell
import Quickshell.Hyprland          // Para acceder a los WorkSpaces
import QtQuick
import QtQuick.Layouts              // Para usar RowLayout o ColumnLayout
import Quickshell.Services.UPower   // Para detectar si hay bateria o no (y no mostrar el icono en un PC de mesa)

ShellRoot {
    Border {
        thickness: 6
        rounding: 22
        frameColor: Theme.background
    }
    Launcher{}    // Widget que se abre/cierra con Super, abajo-derecha
    PanelWindow {
        anchors { top: true; bottom: true; left: true }
        implicitWidth: 32
        color: Theme.background
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
                Volume{Layout.alignment: Qt.AlignHCenter}       // Volumen
                Network{Layout.alignment: Qt.AlignHCenter}      // Wifi
                Bluetooths{Layout.alignment: Qt.AlignHCenter}   // Bluetooth
                Loader{
                    active: UPower.displayDevice.isPresent      // Solo se instancia si hay una batería real (en un PC no se crea el widget)
                    sourceComponent: Battery{}
                    Layout.alignment: Qt.AlignHCenter
                }
            }
            Power{Layout.alignment: Qt.AlignHCenter}            // Apagar / Suspender
        }

    }
}
