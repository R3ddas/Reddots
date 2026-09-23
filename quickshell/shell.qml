// Recursos: https://tonybtw.com/tutorial/quickshell/

import Quickshell
import Quickshell.Hyprland          // Para acceder a los WorkSpaces
import QtQuick
import QtQuick.Layouts              // Para usar RowLayout o ColumnLayout
import Quickshell.Services.UPower   // Para detectar si hay bateria o no (y no mostrar el icono en un PC de mesa)

ShellRoot {

    // Pantalla del portátil si está presente (con la tapa abierta), si no la primera disponible.
    // Así la barra siempre vive en el portátil en vez de en el monitor que Quickshell elija por defecto.
    readonly property var laptopScreen: {
        // Los paneles internos casi siempre usan el prefijo "eDP" (a veces "LVDS" en hardware más antiguo)
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name.startsWith("eDP") || Quickshell.screens[i].name.startsWith("LVDS")) return Quickshell.screens[i]
        }
        return Quickshell.screens[0]
    }

    Border {
        screen: laptopScreen
        frameColor: Theme.background
    }
    Launcher{screen: laptopScreen}    // Widget que se abre/cierra con Super, abajo-derecha
    Notifications{screen: laptopScreen}
    PanelWindow {
        screen: laptopScreen
        anchors { top: true; bottom: true; left: true }
        implicitWidth: Geometry.sidebarWidth
        color: Theme.background
        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            anchors.leftMargin: 6 + Geometry.borderThickness / 2   // Le sumo la mitad del borde que añade "Border"
            anchors.rightMargin: 6 - Geometry.borderThickness / 2  // Le resto la mitad del borde que añade "Border"

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
                GeometrySettings{Layout.alignment: Qt.AlignHCenter}  // Editor de Geometry.qml (ancho barra, grosor/redondeo borde)
                ThemeSettings{Layout.alignment: Qt.AlignHCenter}     // Selector de tema de color (Theme.qml)
                WallpaperSettings{Layout.alignment: Qt.AlignHCenter} // Selector de fondo de pantalla (Wallpaper.qml)
            }
            Power{Layout.alignment: Qt.AlignHCenter}            // Apagar / Suspender
        }

    }
}
