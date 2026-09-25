// Icono de cámara en la barra + popup para hacer capturas de pantalla: de una
// región, de una ventana o de la pantalla entera. Clic derecho en el icono: captura
// de región directamente, sin abrir el menú. El trabajo lo hace scripts/screenshot.sh
// (guarda la imagen, la copia al portapapeles y avisa); esto solo lo lanza.
import Quickshell
import Quickshell.Hyprland          // Para el HyprlandFocusGrab
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    function capture(mode) {
        menu.visible = false        // El script espera un momento a que se cierre antes de capturar
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/scripts/screenshot.sh", mode])
    }

    // Una fila del menú (icono + texto), con el mismo estilo que las de Power.qml
    component MenuRow: Rectangle {
        id: row
        property int icon
        property string label
        property string mode        // Lo que se le pasa a screenshot.sh

        Layout.fillWidth: true
        implicitHeight: 28
        radius: 4
        color: rowMouse.containsMouse ? Theme.surfaceHover : "transparent"

        Item {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8

            Text {
                text: String.fromCodePoint(row.icon)
                color: Theme.textActive
                font.pixelSize: 15
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: row.label
                color: Theme.textActive
                anchors.left: parent.left
                anchors.leftMargin: 28
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.capture(row.mode)
        }
    }

    Text {
        id: iconText
        text: String.fromCodePoint(0xF0100)  // camera
        color: Theme.textActive
        font.pixelSize: 18
        Layout.alignment: Qt.AlignHCenter

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: event => {
                if (event.button === Qt.RightButton) root.capture("region")   // Clic derecho: región directamente
                else menu.visible = !menu.visible                            // Clic izquierdo: abre/cierra el menú
            }
        }
    }

    PopupWindow {
        id: menu
        visible: false
        color: "transparent"

        anchor.item: iconText
        anchor.rect.x: Geometry.sidebarWidth // Que el menú no tape la barra, aparece a partir de su borde derecho
        anchor.gravity: Edges.Bottom | Edges.Right  // Sin "Right" el popup se centra en el punto de anclaje y vuelve a tapar la barra
        anchor.onAnchoring: anchor.rect.y = Geometry.popupY(iconText, anchor.rect.x, implicitHeight)  // A la altura del icono; si no cabe, se mueve lo justo para dejar el mismo hueco que a la izquierda

        implicitWidth: 170
        implicitHeight: listCol.implicitHeight + 16

        onVisibleChanged: {
            if (visible) grabTimer.restart()
            else { grabTimer.stop(); grab.active = false }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.surface
            radius: Geometry.popupRounding                  // Redondeo propio de los desplegables (editable en GeometrySettings)
            border.color: Theme.textSelected                // Borde con el color de acento del tema
            border.width: Geometry.popupBorderWidth         // Grosor editable en GeometrySettings

            ColumnLayout {
                id: listCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                MenuRow { icon: 0xF019E; label: "Región";        mode: "region" }     // crop
                MenuRow { icon: 0xF05AF; label: "Ventana";       mode: "ventana" }    // window-maximize
                MenuRow { icon: 0xF0E51; label: "Pantalla";      mode: "pantalla" }   // monitor-screenshot

                Rectangle {                                 // Separador antes de la carpeta
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.border
                }

                MenuRow { icon: 0xF0770; label: "Abrir carpeta"; mode: "carpeta" }    // folder-open (como en WallpaperSettings.qml)
            }
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [menu]
        active: false
        onCleared: menu.visible = false
    }

    Timer {
        id: grabTimer
        interval: 5
        onTriggered: grab.active = true
    }
}
