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

    // Todas las ventanas van dentro de un Variants: si la pantalla desaparece (monitor
    // apagado, tapa cerrada...) se destruyen, y cuando vuelve se crean de nuevo solas.
    // Sin esto, al volver la pantalla las ventanas no se reenganchaban y la barra
    // desaparecía hasta reiniciar Quickshell.
    Variants {
        model: laptopScreen ? [laptopScreen] : []     // Una sola pantalla (o ninguna mientras no haya)

        Scope {
            id: screenScope
            required property var modelData     // La pantalla en la que se crean las ventanas

            Border {
                screen: screenScope.modelData
                frameColor: Theme.background
            }
            Launcher{screen: screenScope.modelData}    // Widget que se abre/cierra con Super, abajo-derecha
            Notifications{screen: screenScope.modelData}
            Osd{screen: screenScope.modelData}         // Indicador de volumen/brillo al usar las teclas multimedia
            Keybinds{id: keybinds; screen: screenScope.modelData}   // Chuleta de atajos, se abre desde el menú de Reddots
            PanelWindow {
                screen: screenScope.modelData
                anchors { top: true; bottom: true; left: true }
                implicitWidth: Geometry.sidebarWidth
                color: Theme.background
                ColumnLayout {
                    id: barLayout
                    anchors.fill: parent
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    anchors.leftMargin: 6 + Geometry.borderThickness / 2   // Le sumo la mitad del borde que añade "Border"
                    anchors.rightMargin: 6 - Geometry.borderThickness / 2  // Le resto la mitad del borde que añade "Border"

                    Workspaces{Layout.alignment: Qt.AlignHCenter}       // Cambiador de Workspaces
                    Item {                                              // Hueco entre los workspaces y el grupo inferior (lo empuja hacia abajo); el reloj va dentro
                        id: clockSpace
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Clock{                                          // Reloj
                            anchors.horizontalCenter: parent.horizontalCenter
                            // Centrado en la pantalla (el layout tiene el mismo margen arriba y abajo, así que su centro es el de la barra),
                            // no entre los dos grupos. Sin salirse del hueco: si el grupo inferior crece tanto que lo taparía, sube lo justo
                            y: Math.round(Math.max(0, Math.min(clockSpace.height - height, barLayout.height / 2 - height / 2 - clockSpace.y)))
                        }
                    }
                    ColumnLayout{
                        spacing: 5
                        Layout.alignment: Qt.AlignHCenter                // Sin esto el grupo queda pegado a la izquierda (es más estrecho que la barra) y sus iconos se descentran
                        Volume{Layout.alignment: Qt.AlignHCenter}       // Volumen
                        Network{Layout.alignment: Qt.AlignHCenter}      // Wifi
                        Bluetooths{Layout.alignment: Qt.AlignHCenter}   // Bluetooth
                        Loader{
                            active: UPower.displayDevice.isPresent      // Solo se instancia si hay una batería real (en un PC no se crea el widget)
                            sourceComponent: Battery{}
                            Layout.alignment: Qt.AlignHCenter
                        }
                        SettingsToggle{id: settingsToggle; Layout.alignment: Qt.AlignHCenter}  // Muestra/oculta el grupo de configuración de debajo
                        ColumnLayout{
                            visible: settingsToggle.expanded                     // Oculto, el layout no le reserva hueco
                            spacing: 5
                            Layout.alignment: Qt.AlignHCenter
                            Screenshot{Layout.alignment: Qt.AlignHCenter}        // Capturas de pantalla
                            Brightness{Layout.alignment: Qt.AlignHCenter}        // Brillo del portátil y de los monitores externos (DDC)
                            GeometrySettings{Layout.alignment: Qt.AlignHCenter}  // Editor de Geometry.qml (ancho barra, grosor/redondeo borde)
                            ThemeSettings{Layout.alignment: Qt.AlignHCenter}     // Selector de tema de color (Theme.qml)
                            WallpaperSettings{Layout.alignment: Qt.AlignHCenter} // Selector de fondo de pantalla (Wallpaper.qml)
                            Reddots{                                             // Lo relativo al repo: chuleta de atajos y actualizar Reddots
                                Layout.alignment: Qt.AlignHCenter
                                onKeybindsRequested: keybinds.visible = true
                            }
                            SettingsToggle{controls: settingsToggle; Layout.alignment: Qt.AlignHCenter}  // Copia del engranaje al final del grupo: se oculta con él y hace lo mismo
                        }
                    }
                    Power{Layout.alignment: Qt.AlignHCenter}            // Apagar / Suspender
                }
            }
        }
    }
}
