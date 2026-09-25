// Icono de cámara en la barra + popup para hacer capturas de pantalla: de una
// región, de una ventana o de la pantalla entera. Clic derecho en el icono: captura
// de región directamente, sin abrir el menú. El trabajo lo hace scripts/screenshot.sh
// (guarda la imagen, la copia al portapapeles y avisa); esto solo lo lanza.
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    function capture(mode) {
        menu.visible = false        // El script espera un momento a que se cierre antes de capturar
        Quickshell.execDetached([Quickshell.shellPath("scripts/screenshot.sh"), mode])
    }

    BarIcon {
        id: iconText
        text: String.fromCodePoint(0xF0100)  // camera
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) root.capture("region")   // Clic derecho: región directamente
            else menu.toggle()                                           // Clic izquierdo: abre/cierra el menú
        }
    }

    BarPopup {
        id: menu
        anchorItem: iconText
        implicitWidth: 170
        implicitHeight: listCol.implicitHeight + 16

        ColumnLayout {
            id: listCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            MenuRow { icon: String.fromCodePoint(0xF019E); text: "Región";   onClicked: root.capture("region") }     // crop
            MenuRow { icon: String.fromCodePoint(0xF05AF); text: "Ventana";  onClicked: root.capture("ventana") }    // window-maximize
            MenuRow { icon: String.fromCodePoint(0xF0E51); text: "Pantalla"; onClicked: root.capture("pantalla") }   // monitor-screenshot

            Rectangle {                                 // Separador antes de la carpeta
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }

            MenuRow { icon: String.fromCodePoint(0xF0770); text: "Abrir carpeta"; onClicked: root.capture("carpeta") }   // folder-open (como en WallpaperSettings.qml)
        }
    }
}
