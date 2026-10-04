// Bar.qml
// La barra lateral izquierda con todos sus widgets. La crea shell.qml, una por
// pantalla de la barra (ver laptopScreen allí).

import Quickshell
import QtQuick
import QtQuick.Layouts              // Para usar RowLayout o ColumnLayout
import Quickshell.Services.UPower   // Para detectar si hay batería o no (y no mostrar el icono en un PC de mesa)
import qs.bar.settings              // El engranaje (SettingsToggle) y todo lo que se pliega con él
import qs.services

PanelWindow {
    id: root

    // Desde el menú de Reddots: abrir la chuleta de atajos. Quién la abre lo decide shell.qml
    signal keybindsRequested()

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

        Reddots{                                            // Logo arriba del todo, siempre visible: chuleta de atajos y actualizar Reddots
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 4                          // Algo de aire entre el logo y los workspaces
            onKeybindsRequested: root.keybindsRequested()
        }
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
            Layout.fillWidth: true                           // Ancho fijo (el de barLayout), para que un icono más ancho/estrecho (p.ej. el de wifi al cambiar de estado) no desplace a todos los demás al recalcular el ancho del grupo
            Layout.maximumWidth: Infinity                    // Sin esto fillWidth no hace nada: el máximo de un layout es el ancho de su hijo más ancho (los hijos sin fillWidth no crecen), así que el grupo seguía midiendo lo que su icono más ancho y al cambiar este se movía todo 1 px por redondeo
            Tray{Layout.alignment: Qt.AlignHCenter}         // Bandeja del sistema (iconos de Steam, Teams...); sin apps no ocupa sitio
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
                Layout.fillWidth: true                               // Igual que el grupo de arriba: ancho fijo para que ningún icono de dentro desplace a los demás
                Layout.maximumWidth: Infinity                        // Igual que arriba: sin esto fillWidth queda limitado al ancho del icono más ancho
                SystemStats{Layout.alignment: Qt.AlignHCenter}       // Uso del sistema: procesador, memoria y temperaturas
                Screenshot{Layout.alignment: Qt.AlignHCenter}        // Capturas de pantalla
                Brightness{Layout.alignment: Qt.AlignHCenter}        // Brillo del portátil y de los monitores externos (DDC)
                GeometrySettings{Layout.alignment: Qt.AlignHCenter}  // Editor de Geometry.qml (ancho barra, grosor/redondeo borde)
                ThemeSettings{Layout.alignment: Qt.AlignHCenter}     // Selector de tema de color (Theme.qml)
                WallpaperSettings{Layout.alignment: Qt.AlignHCenter} // Selector de fondo de pantalla (Wallpaper.qml)
                SettingsToggle{controls: settingsToggle; Layout.alignment: Qt.AlignHCenter}  // Copia del engranaje al final del grupo: se oculta con él y hace lo mismo
            }
        }
        Power{Layout.alignment: Qt.AlignHCenter}            // Apagar / Suspender
    }
}
